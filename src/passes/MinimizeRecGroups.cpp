/*
 * Copyright 2024 WebAssembly Community Group participants
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Split types into minimal recursion groups by computing the strongly connected
// components of the type graph, which are the minimal sets of
// mutually-recursive types that must be in the same recursion group with each
// other for the type section to validate.
//
// We must additionally ensure that distinct types remain distinct, which would
// not be the case if we allowed two separate strongly connected components with
// the same shape to be rewritten to two copies of the same recursion group.
// Accidentally merging types would be incorrect because it would change the
// behavior of casts that would have previously been able to differentiate the
// types.
//
// When multiple strongly connected components have the same shape, first try to
// differentiate them by permuting their types, which keeps the sizes of the rec
// groups as small as possible. When there are more strongly connected
// components that are permutations of one another than there are distinct
// permutations, fall back to keeping the types distinct by adding distinct
// brand types to the recursion groups to ensure they have different shapes.
//
// There are several possible algorithmic designs for detecting when to generate
// permutations and determining what permutations to generate. They trade off
// the amount of "wasted" work spent generating shapes that have already been
// used with the amount of work spent trying to avoid the wasted work and with
// the quality of the output.
//
// The simplest possible design that avoids all "wasted" work would be to
// canonicalize the shape of each group to eagerly detect isomorphisms and
// eagerly organize the groups into equivalence classes. This would allow us to
// avoid ever generating permutations of a group with shapes that have already
// been used. See `getCanonicalPermutation` below for details on how this works.
// However, this is not an ideal solution because canonicalization is an
// expensive operation and in the common case a group's shape will not conflict
// with any other group's shape, so canonicalization itself would be wasted
// work.
//
// The simplest possible design in the other direction is to never canonicalize
// and instead to lazily build up equivalences classes of isomorphic groups when
// shape conflicts are detected in practice. Conflicts are resolved by choosing
// the next permutation generated by the representative element of the
// equivalence class. This solution is not ideal because groups with high
// symmetry can have very many permutations that have the same shape, so many
// permutations might need to be generated before finding one that is distinct
// from previous permutations with respect to its shape. This work can be
// sidestepped by instead eagerly advancing the brand type, but that increases
// the code size of the output.
//
// The design chosen here is a hybrid of those two designs that is slightly more
// complicated, but gets the best of both worlds. We lazily detect equivalence
// classes of groups without eager shape canonicalization like in the second
// design, but we canonicalize the shape for any equivalence class that grows
// larger than one group like in the first design. This ensures that we don't
// spend time canonicalizing in the common case where there are no shape
// conflicts, but it also ensures that we don't waste time generating
// permutations with shapes that conflict with the shapes of previous groups. It
// also allows us to avoid compromising on the quality of the output.

#include "ir/module-utils.h"
#include "ir/type-updating.h"
#include "pass.h"
#include "support/disjoint_sets.h"
#include "support/strongly_connected_components.h"
#include "support/topological_sort.h"
#include "wasm-type-shape.h"
#include "wasm.h"

namespace wasm {

namespace {

// Compute the strongly connected components of the private types, being sure to
// only consider edges to other private types.
struct TypeSCCs
  : SCCs<typename std::vector<HeapType>::const_iterator, TypeSCCs> {
  std::unordered_set<HeapType> includedTypes;
  TypeSCCs(const std::vector<HeapType>& types)
    : SCCs(types.begin(), types.end()),
      includedTypes(types.cbegin(), types.cend()) {}
  void pushChildren(HeapType parent) {
    for (auto child : parent.getReferencedHeapTypes()) {
      if (includedTypes.count(child)) {
        push(child);
      }
    }
  }
};

// After all their permutations with distinct shapes have been used, different
// groups with the same shapes must be differentiated by adding in a "brand"
// type. Even with a brand mixed in, we might run out of permutations with
// distinct shapes, in which case we need a new brand type. This iterator
// provides an infinite sequence of possible brand types, prioritizing those
// with the most compact encoding.
struct BrandTypeIterator {
  // See `initFieldOptions` for the 18 options.
  static constexpr Index optionCount = 18;
  static std::array<Field, optionCount> fieldOptions;
  static void initFieldOptions();

  struct FieldInfo {
    uint8_t index = 0;
    bool immutable = false;

    operator Field() const {
      auto field = fieldOptions[index];
      if (immutable) {
        field.mutable_ = Immutable;
      }
      return field;
    }

    bool advance() {
      if (!immutable) {
        immutable = true;
        return true;
      }
      immutable = false;
      index = (index + 1) % optionCount;
      return index != 0;
    }
  };

  bool useArray = false;
  std::vector<FieldInfo> fields;

  HeapType operator*() const {
    if (useArray) {
      return Array(fields[0]);
    }
    return Struct(std::vector<Field>(fields.begin(), fields.end()));
  }

  BrandTypeIterator& operator++() {
    for (Index i = fields.size(); i > 0; --i) {
      if (fields[i - 1].advance()) {
        return *this;
      }
    }
    if (useArray) {
      useArray = false;
      return *this;
    }
    fields.emplace_back();
    useArray = fields.size() == 1;
    return *this;
  }
};

// Create an adjacency list with edges from supertype to subtype and from
// described type to descriptor.
std::vector<std::vector<Index>>
createTypeOrderGraph(const std::vector<HeapType>& types) {
  std::unordered_map<HeapType, Index> indices;
  for (auto type : types) {
    indices.insert({type, indices.size()});
  }

  std::vector<std::vector<Index>> typeOrderGraph(types.size());
  for (Index i = 0; i < types.size(); ++i) {
    if (auto super = types[i].getDeclaredSuperType()) {
      if (auto it = indices.find(*super); it != indices.end()) {
        typeOrderGraph[it->second].push_back(i);
      }
    }
    if (auto desc = types[i].getDescribedType()) {
      // Described types must be in the same SCC / rec group.
      auto it = indices.find(*desc);
      assert(it != indices.end());
      typeOrderGraph[it->second].push_back(i);
    }
  }
  return typeOrderGraph;
}

struct RecGroupInfo;

// As we iterate through the strongly connected components, we may find
// components that have the same shape. When we find such a collision, we merge
// the groups for the components into a single equivalence class where we track
// how we have disambiguated all such isomorphic groups.
struct GroupClassInfo {
  // If the group has just a single type, record it so we can make sure the
  // brand is not identical to it.
  std::optional<HeapType> singletonType;
  // If we have gone through all the permutations of this group with distinct
  // shapes, we need to add a brand type to continue differentiating different
  // groups in the class.
  std::optional<BrandTypeIterator> brand;
  // An adjacency list giving edges from supertypes to subtypes within the
  // group, using indices into the (non-materialized) canonical shape of this
  // group, offset by 1 iff there is a brand type. Used to ensure that we only
  // find emit permutations that respect the constraint that supertypes must be
  // ordered before subtypes.
  std::vector<std::vector<Index>> typeOrderGraph;
  // A generator of valid permutations of the components in this class.
  TopologicalOrders orders;

  // Initialize `typeOrderGraph` and `orders` based on the canonical ordering
  // encoded by the group and permutation in `info`.
  static std::vector<std::vector<Index>> initTypeOrderGraph(RecGroupInfo& info);
  GroupClassInfo(RecGroupInfo& info);

  void advance(FeatureSet features) {
    ++orders;
    if (orders == orders.end()) {
      advanceBrand(features);
    }
  }

  void advanceBrand(FeatureSet features) {
    if (brand) {
      ++*brand;
    } else {
      brand.emplace();
      // Make room in the subtype graph for the brand type, which goes at the
      // beginning of the canonical order.
      typeOrderGraph.insert(typeOrderGraph.begin(), {{}});
      // Adjust indices.
      for (Index i = 1; i < typeOrderGraph.size(); ++i) {
        for (auto& edge : typeOrderGraph[i]) {
          ++edge;
        }
      }
    }
    // Make sure the brand is not the same as the real type.
    if (singletonType && RecGroupShape({**brand}, features) ==
                           RecGroupShape({*singletonType}, features)) {
      ++*brand;
    }
    // Start back at the initial permutation with the new brand.
    orders.~TopologicalOrders();
    new (&orders) TopologicalOrders(typeOrderGraph);
  }

  // Permute the types in the given group to match the current configuration in
  // this GroupClassInfo.
  void permute(RecGroupInfo&);
};

// The information we keep for each produced rec group.
struct RecGroupInfo {
  // The sequence of input types to be rewritten into this output group.
  std::vector<HeapType> group;
  // The permutation of the canonical shape for this group's class used to
  // arrive at this group's shape. Used when we later find another strongly
  // connected component with this shape to apply the inverse permutation and
  // get that other component's types into the canonical shape before using a
  // fresh permutation to re-shuffle them into their final shape. Only set for
  // groups belonging to nontrivial equivalence classes.
  std::vector<Index> permutation;
  // Does this group include a brand type that does not correspond to a type in
  // the original module?
  bool hasBrand = false;
  // This group may be the representative group for its nontrivial equivalence
  // class, in which case it holds the necessary extra information used to add
  // new groups to the class.
  std::optional<GroupClassInfo> classInfo;
};

std::vector<std::vector<Index>>
GroupClassInfo::initTypeOrderGraph(RecGroupInfo& info) {
  assert(!info.classInfo);
  assert(info.permutation.size() == info.group.size());

  std::vector<HeapType> canonical(info.group.size());
  for (Index i = 0; i < info.group.size(); ++i) {
    canonical[info.permutation[i]] = info.group[i];
  }

  return createTypeOrderGraph(canonical);
}

GroupClassInfo::GroupClassInfo(RecGroupInfo& info)
  : singletonType(info.group.size() == 1
                    ? std::optional<HeapType>(info.group[0])
                    : std::nullopt),
    brand(std::nullopt), typeOrderGraph(initTypeOrderGraph(info)),
    orders(typeOrderGraph) {}

void GroupClassInfo::permute(RecGroupInfo& info) {
  assert(info.group.size() == info.permutation.size());
  bool insertingBrand = info.group.size() < typeOrderGraph.size();
  // First, un-permute the group to get back to the canonical order, offset by 1
  // if we are newly inserting a brand.
  std::vector<HeapType> canonical(info.group.size() + insertingBrand);
  for (Index i = 0; i < info.group.size(); ++i) {
    canonical[info.permutation[i] + insertingBrand] = info.group[i];
  }
  // Update the brand.
  if (brand) {
    canonical[0] = **brand;
  }
  if (insertingBrand) {
    info.group.resize(info.group.size() + 1);
    info.hasBrand = true;
  }
  // Finally, re-permute with the new permutation..
  info.permutation = *orders;
  for (Index i = 0; i < info.group.size(); ++i) {
    info.group[i] = canonical[info.permutation[i]];
  }
}

std::array<Field, BrandTypeIterator::optionCount>
  BrandTypeIterator::fieldOptions = {{}};

void BrandTypeIterator::initFieldOptions() {
  BrandTypeIterator::fieldOptions = {{
    Field(Field::i8, Mutable),
    Field(Field::i16, Mutable),
    Field(Type::i32, Mutable),
    Field(Type::i64, Mutable),
    Field(Type::f32, Mutable),
    Field(Type::f64, Mutable),
    Field(Type(HeapType::any, Nullable), Mutable),
    Field(Type(HeapType::func, Nullable), Mutable),
    Field(Type(HeapType::ext, Nullable), Mutable),
    Field(Type(HeapType::none, Nullable), Mutable),
    Field(Type(HeapType::nofunc, Nullable), Mutable),
    Field(Type(HeapType::noext, Nullable), Mutable),
    Field(Type(HeapType::any, NonNullable), Mutable),
    Field(Type(HeapType::func, NonNullable), Mutable),
    Field(Type(HeapType::ext, NonNullable), Mutable),
    Field(Type(HeapType::none, NonNullable), Mutable),
    Field(Type(HeapType::nofunc, NonNullable), Mutable),
    Field(Type(HeapType::noext, NonNullable), Mutable),
  }};
}

struct MinimizeRecGroups : Pass {
  // The types we are optimizing and their indices in this list.
  std::vector<HeapType> types;

  // A global ordering on all types, including public types. Used to define a
  // total ordering on rec group shapes.
  std::unordered_map<HeapType, Index> typeIndices;

  // As we process strongly connected components, we will construct output
  // recursion groups here.
  std::vector<RecGroupInfo> groups;

  // For each shape of rec group we have created, its index in `groups`.
  std::unordered_map<RecGroupShape, Index> groupShapeIndices;

  // A sentinel index for public group shapes, which are recorded in
  // `groupShapeIndices` but not in `groups`.
  static constexpr Index PublicGroupIndex = -1;

  // Since we won't store public groups in `groups`, we need this separate place
  // to store their types referred to by their `RecGroupShape`s.
  std::vector<std::vector<HeapType>> publicGroupTypes;

  // When we find that two groups are isomorphic to (i.e. permutations of) each
  // other, we combine their equivalence classes and choose a new class
  // representative to use to disambiguate the groups and any further groups
  // that will join the class.
  DisjointSets equivalenceClasses;

  // When we see a new group, we have to make sure its shape doesn't conflict
  // with the shape of any existing group. If there is a conflict, we need to
  // update the group's shape and try again. Maintain a stack of group indices
  // whose shapes we need to check for uniqueness to avoid deep recursions.
  std::vector<Index> shapesToUpdate;

  // The comparison of rec group shapes depends on the features.
  FeatureSet features;

  void run(Module* module) override {
    features = module->features;
    // There are no recursion groups to minimize if GC is not enabled.
    if (!features.hasGC()) {
      return;
    }

    initBrandOptions();

    auto typeInfo = ModuleUtils::collectHeapTypeInfo(
      *module,
      ModuleUtils::TypeInclusion::AllTypes,
      ModuleUtils::VisibilityHandling::FindVisibility);

    types.reserve(typeInfo.size());

    // We cannot optimize public types, but we do need to make sure we don't
    // generate new groups with the same shape.
    std::unordered_set<RecGroup> publicGroups;
    for (auto& [type, info] : typeInfo) {
      if (info.visibility == ModuleUtils::Visibility::Private) {
        // We can optimize private types.
        types.push_back(type);
        typeIndices.insert({type, typeIndices.size()});
      } else {
        publicGroups.insert(type.getRecGroup());
      }
    }

    publicGroupTypes.reserve(publicGroups.size());
    for (auto group : publicGroups) {
      publicGroupTypes.emplace_back(group.begin(), group.end());
      [[maybe_unused]] auto [_, inserted] = groupShapeIndices.insert(
        {RecGroupShape(publicGroupTypes.back(), features), PublicGroupIndex});
      assert(inserted);
    }

    // The number of types to optimize is an upper bound on the number of
    // recursion groups we will emit.
    groups.reserve(types.size());

    // Compute the strongly connected components and ensure they form distinct
    // recursion groups.
    for (auto scc : TypeSCCs(types)) {
      [[maybe_unused]] Index index = equivalenceClasses.addSet();
      assert(index == groups.size());
      groups.emplace_back();

      // The SCC is not necessarily topologically sorted to have the supertypes
      // and described types come first. Fix that.
      std::vector<HeapType> sccTypes(scc.begin(), scc.end());
      auto deps = createTypeOrderGraph(sccTypes);
      auto permutation = *TopologicalOrders(deps).begin();
      groups.back().group.resize(sccTypes.size());
      for (Index i = 0; i < sccTypes.size(); ++i) {
        groups.back().group[i] = sccTypes[permutation[i]];
      }
      assert(shapesToUpdate.empty());
      shapesToUpdate.push_back(index);
      updateShapes();
    }

    rewriteTypes(*module);
  }

  void initBrandOptions() {
    // Initialize the field options for brand types lazily here to avoid
    // depending on global constructor ordering.
    [[maybe_unused]] static bool fieldsInitialized = []() {
      BrandTypeIterator::initFieldOptions();
      return true;
    }();
  }

  void updateShapes() {
    while (!shapesToUpdate.empty()) {
      auto index = shapesToUpdate.back();
      shapesToUpdate.pop_back();
      updateShape(index);
    }
  }

  void updateShape(Index group) {
    auto [it, inserted] = groupShapeIndices.insert(
      {RecGroupShape(groups[group].group, features), group});
    if (inserted) {
      // This shape was unique. We're done.
      return;
    }

    // We have a conflict. There are seven possibilities:
    //
    //   0. We have a conflict with a public group and...
    //
    //     A. We are trying to insert the next permutation of an existing
    //        equivalence class.
    //
    //     B. We are inserting a new group not yet affiliated with a nontrivial
    //        equivalence class.
    //
    //   1. We are trying to insert the next permutation of an existing
    //      equivalence class and have found that...
    //
    //     A. The next permutation has the same shape as some previous
    //        permutation in the same equivalence class.
    //
    //     B. The next permutation has the same shape as some other group
    //        already in a different nontrivial equivalent class.
    //
    //     C. The next permutation has the same shape as some other group
    //        not yet included in a nontrivial equivalence class.
    //
    //   2. We are inserting a new group not yet affiliated with a
    //      nontrivial equivalence class and have found that...
    //
    //     A. It has the same shape as some group in an existing nontrivial
    //        equivalence class.
    //
    //     B. It has the same shape as some other group also not yet affiliated
    //        with a nontrivial equivalence class, so we will form a new
    //        nontrivial equivalence class.
    //
    // These possibilities are handled in order below.

    auto& groupInfo = groups[group];
    Index groupRep = equivalenceClasses.getRoot(group);

    Index other = it->second;

    if (other == PublicGroupIndex) {
      // The group currently has the same shape as some public group. We can't
      // change the public group, so we need to change the shape of the current
      // group.
      //
      // Case 0A: Since we already have a nontrivial equivalence class, we can
      // try the next permutation to avoid conflict with the public group.
      if (groups[groupRep].classInfo) {
        // We have everything we need to generate the next permutation of this
        // group.
        auto& classInfo = *groups[groupRep].classInfo;
        classInfo.advance(features);
        classInfo.permute(groupInfo);
        shapesToUpdate.push_back(group);
        return;
      }

      // Case 0B: There is no nontrivial equivalence class yet. Create one so
      // we have all the information we need to try a different permutation.
      assert(group == groupRep);
      groupInfo.permutation = getCanonicalPermutation(groupInfo.group);
      groupInfo.classInfo.emplace(groupInfo);
      groupInfo.classInfo->permute(groupInfo);
      shapesToUpdate.push_back(group);
      return;
    }

    auto& otherInfo = groups[other];
    Index otherRep = equivalenceClasses.getRoot(other);

    // Case 1A: We have found a permutation of this group that has the same
    // shape as a previous permutation of this group. Skip the rest of the
    // permutations, which will also have the same shapes as previous
    // permutations.
    if (groupRep == otherRep) {
      assert(groups[groupRep].classInfo);
      auto& classInfo = *groups[groupRep].classInfo;

      // Move to the next permutation after advancing the type brand to skip
      // further repeated shapes.
      classInfo.advanceBrand(features);
      classInfo.permute(groupInfo);

      shapesToUpdate.push_back(group);
      return;
    }

    // Case 1B: There is a shape conflict with a group from a different
    // nontrivial equivalence class. Because we canonicalize the shapes whenever
    // we first create a nontrivial equivalence class, this is usually not
    // possible; two equivalence classes with groups of the same shape should
    // actually be the same equivalence class. The exception is when there is a
    // group in each class whose brand matches the base type of the other class.
    // In this case we don't actually want to join the classes; we just want to
    // advance the current group to the next permutation to resolve the
    // conflict.
    if (groups[groupRep].classInfo && groups[otherRep].classInfo) {
      auto& classInfo = *groups[groupRep].classInfo;
      classInfo.advance(features);
      classInfo.permute(groupInfo);
      shapesToUpdate.push_back(group);
      return;
    }

    // Case 1C: The current group belongs to a nontrivial equivalence class and
    // has the same shape as some other group unaffiliated with a nontrivial
    // equivalence class. Bring that other group into our equivalence class and
    // advance the current group to the next permutation to resolve the
    // conflict.
    if (groups[groupRep].classInfo) {
      auto& classInfo = *groups[groupRep].classInfo;

      [[maybe_unused]] Index unionRep =
        equivalenceClasses.getUnion(groupRep, otherRep);
      assert(groupRep == unionRep);

      // `other` must have the same permutation as `group` because they have the
      // same shape. Advance `group` to the next permutation.
      otherInfo.classInfo = std::nullopt;
      otherInfo.permutation = groupInfo.permutation;
      classInfo.advance(features);
      classInfo.permute(groupInfo);

      shapesToUpdate.push_back(group);
      return;
    }

    // Case 2A: The shape of the current group is already found in an existing
    // nontrivial equivalence class. Join the class and advance to the next
    // permutation to resolve the conflict.
    if (groups[otherRep].classInfo) {
      auto& classInfo = *groups[otherRep].classInfo;

      [[maybe_unused]] Index unionRep =
        equivalenceClasses.getUnion(otherRep, groupRep);
      assert(otherRep == unionRep);

      // Since we matched shapes with `other`, unapplying its permutation gets
      // us back to the canonical shape, from which we can apply a fresh
      // permutation.
      groupInfo.classInfo = std::nullopt;
      groupInfo.permutation = otherInfo.permutation;
      classInfo.advance(features);
      classInfo.permute(groupInfo);

      shapesToUpdate.push_back(group);
      return;
    }

    // Case 2B: We need to join two groups with matching shapes into a new
    // nontrivial equivalence class.
    assert(!groups[groupRep].classInfo && !groups[otherRep].classInfo);
    assert(group == groupRep && other == otherRep);

    // We are canonicalizing and reinserting the shape for other, so remove it
    // from the map under its current shape.
    groupShapeIndices.erase(it);

    // Put the types for both groups into the canonical order.
    auto permutation = getCanonicalPermutation(groupInfo.group);
    groupInfo.permutation = otherInfo.permutation = std::move(permutation);

    // Set up `other` to be the representative element of the equivalence class.
    otherInfo.classInfo.emplace(otherInfo);
    auto& classInfo = *otherInfo.classInfo;

    // Update both groups to have the initial valid order. Their shapes still
    // match.
    classInfo.permute(otherInfo);
    classInfo.permute(groupInfo);

    // Insert `other` with its new shape. It may end up being joined to another
    // existing equivalence class, in which case its class info will be cleared
    // and `group` will subsequently be added to that same existing class, or
    // alternatively it may be inserted as the representative element of a new
    // class to which `group` will subsequently be joined.
    shapesToUpdate.push_back(group);
    shapesToUpdate.push_back(other);
  }

  std::vector<Index>
  getCanonicalPermutation(const std::vector<HeapType>& types) {
    // The correctness of this part depends on some interesting properties of
    // strongly connected graphs with ordered, directed edges. A permutation of
    // the vertices in a graph is an isomorphism that produces an isomorphic
    // graph. An automorphism is an isomorphism of a structure onto itself, so
    // an automorphism of a graph is a permutation of the vertices that does not
    // change the label-independent properties of a graph. Permutations can be
    // described in terms of sets of cycles of elements.
    //
    // As an example, consider this strongly-connected recursion group:
    //
    //     (rec
    //       (type $a1 (struct (field (ref $a2) (ref $b1))))
    //       (type $a2 (struct (field (ref $a1) (ref $b2))))
    //       (type $b1 (struct (field (ref $b2) (ref $a1))))
    //       (type $b2 (struct (field (ref $b1) (ref $a2))))
    //     )
    //
    // This group has one nontrivial automorphism: ($a1 $a2) ($b1 $b2). Applying
    // this automorphism gives this recursion group:
    //
    //     (rec
    //       (type $a2 (struct (field (ref $a1) (ref $b2))))
    //       (type $a1 (struct (field (ref $a2) (ref $b1))))
    //       (type $b2 (struct (field (ref $b1) (ref $a2))))
    //       (type $b1 (struct (field (ref $b2) (ref $a1))))
    //     )
    //
    // We can verify that the permutation was an automorphism by checking that
    // the label-independent properties of these two rec groups are the same.
    // Indeed, when we write the adjacency matrices with ordered edges for the
    // two graphs, they both come out to this:
    //
    //     0: _ 0 1 _
    //     1: 0 _ _ 1
    //     2: 1 _ _ 0
    //     3: _ 1 0 _
    //
    // In addition to having the same adjacency matrix, the two recursion groups
    // have the same vertex colorings since all of their types have the same
    // top-level structure. Since the label-independent properties of the
    // recursion groups (i.e. all the properties except the intended type
    // identity at each index) are the same, the permutation that takes one
    // group to the other is an automorphism. These are precisely the
    // permutations that do not change a recursion group's shape, so would not
    // change type identity under WebAssembly's isorecursive type system. In
    // other words, automorphisms cannot help us resolve shape conflicts, so we
    // want to avoid generating them.
    //
    // Theorem 1: All cycles in an automorphism of a strongly-connected
    // recursion group are the same size.
    //
    //     Proof: By contradiction. Assume there are two cycles of different
    //     sizes. Because the group is strongly connected, there is a path from
    //     an element in the smaller of these cycles to an element in the
    //     larger. This path must contain an edge between two vertices in cycles
    //     of different sizes N and M such that N < M. Apply the automorphism N
    //     times. The source of this edge has been cycled back to its original
    //     index, but the destination is not yet back at its original index, so
    //     the edge's destination index is different from its original
    //     destination index and the permutation we applied was not an
    //     automorphism after all.
    //
    // Corollary 1.1: No nontrivial automorphism of an SCC may have a stationary
    // element, since either all the cycles have size 1 and the automorphism is
    // trivial or all the cycles have some other size and there are no
    // stationary elements.
    //
    // Corollary 1.2: No two distinct permutations of an SCC with the same first
    // element (e.g. both with some type $t as the first element) have the same
    // shape, since no nontrivial automorphism can keep the first element
    // stationary while mapping one permutation to the other.
    //
    // Find a canonical ordering of the types in this group. The ordering must
    // be independent of the initial order of the types. To do so, consider the
    // orderings given by visitation order on a tree search rooted at each type
    // in the group. Since the group is strongly connected, a tree search from
    // any of types will visit all types in the group, so it will generate a
    // total and deterministic ordering of the types in the group. We can
    // compare the shapes of each of these orderings to organize the root
    // types and their generated orderings into ordered equivalence classes.
    // These equivalence classes each correspond to a cycle in an automorphism
    // of the graph because their elements are vertices that can all occupy the
    // initial index of the graph without the graph structure changing. We can
    // choose an arbitrary ordering from the least equivalence class as a
    // canonical ordering because all orderings in that class describe the same
    // label-independent graph.
    //
    // Compute the orderings generated by DFS on each type.
    std::unordered_set<HeapType> typeSet(types.begin(), types.end());
    std::vector<std::vector<HeapType>> dfsOrders(types.size());
    for (Index i = 0; i < types.size(); ++i) {
      dfsOrders[i].reserve(types.size());
      std::vector<HeapType> workList;
      workList.push_back(types[i]);
      std::unordered_set<HeapType> seen;
      while (!workList.empty()) {
        auto curr = workList.back();
        workList.pop_back();
        if (!typeSet.count(curr)) {
          continue;
        }
        if (seen.insert(curr).second) {
          dfsOrders[i].push_back(curr);
          auto children = curr.getReferencedHeapTypes();
          for (auto child : children) {
            workList.push_back(child);
          }
        }
      }
      assert(dfsOrders[i].size() == types.size());
    }

    // Organize the orderings into equivalence classes, mapping equivalent
    // shapes to lists of automorphically equivalent root types.
    std::map<ComparableRecGroupShape, std::vector<HeapType>> typeClasses;
    for (const auto& order : dfsOrders) {
      ComparableRecGroupShape shape(
        order, features, [this](HeapType a, HeapType b) {
          return this->typeIndices.at(a) < this->typeIndices.at(b);
        });
      typeClasses[shape].push_back(order[0]);
    }

    // Choose the initial canonical ordering.
    const auto& leastOrder = typeClasses.begin()->first.types;

    // We want our canonical ordering to have the additional property that it
    // contains one type from each equivalence class before a second type of any
    // equivalence class. Since our utility for enumerating the topological
    // sorts of the canonical order keeps the initial element fixed as long as
    // possible before moving to the next one, by Corollary 1.2 and because
    // permutations that begin with types in different equivalence class cannot
    // have the same shape (otherwise those initial types would be in the same
    // equivalence class), this will maximize the number of distinct shapes the
    // utility emits before starting to emit permutations that have the same
    // shapes as previous permutations. Since all the type equivalence classes
    // are the same size by Theorem 1, we can assemble the final order by
    // striping across the equivalence classes. We determine the order of types
    // taken from each equivalence class by sorting them by order of appearance
    // in the least order, which ensures the final order remains independent of
    // the initial order.
    std::unordered_map<HeapType, Index> indexInLeastOrder;
    for (auto type : leastOrder) {
      indexInLeastOrder.insert({type, indexInLeastOrder.size()});
    }
    auto classSize = typeClasses.begin()->second.size();
    for (auto& [shape, members] : typeClasses) {
      assert(members.size() == classSize);
      std::sort(members.begin(), members.end(), [&](HeapType a, HeapType b) {
        return indexInLeastOrder.at(a) < indexInLeastOrder.at(b);
      });
    }
    std::vector<HeapType> finalOrder;
    finalOrder.reserve(types.size());
    for (Index i = 0; i < classSize; ++i) {
      for (auto& [shape, members] : typeClasses) {
        finalOrder.push_back(members[i]);
      }
    }

    // Now what we actually want is the permutation that takes us from the final
    // canonical order to the original order of the types.
    std::unordered_map<HeapType, Index> indexInFinalOrder;
    for (auto type : finalOrder) {
      indexInFinalOrder.insert({type, indexInFinalOrder.size()});
    }
    std::vector<Index> permutation;
    permutation.reserve(types.size());
    for (auto type : types) {
      permutation.push_back(indexInFinalOrder.at(type));
    }
    return permutation;
  }

  void rewriteTypes(Module& wasm) {
    // Map types to indices in the builder.
    std::unordered_map<HeapType, Index> outputIndices;
    Index i = 0;
    for (const auto& group : groups) {
      for (Index j = 0; j < group.group.size(); ++j) {
        // Skip the brand if it exists.
        if (!group.hasBrand || group.permutation[j] != 0) {
          outputIndices.insert({group.group[j], i});
        }
        ++i;
      }
    }

    // Build the types.
    TypeBuilder builder(i);
    i = 0;
    for (const auto& group : groups) {
      builder.createRecGroup(i, group.group.size());
      for (auto type : group.group) {
        builder[i++].copy(type, [&](HeapType ht) -> HeapType {
          if (auto it = outputIndices.find(ht); it != outputIndices.end()) {
            return builder[it->second];
          }
          return ht;
        });
      }
    }
    auto built = builder.build();
    assert(built);
    auto newTypes = *built;

    // Replace the types in the module.
    std::unordered_map<HeapType, HeapType> oldToNew;
    i = 0;
    for (const auto& group : groups) {
      for (Index j = 0; j < group.group.size(); ++j) {
        // Skip the brand again if it exists.
        if (!group.hasBrand || group.permutation[j] != 0) {
          oldToNew[group.group[j]] = newTypes[i];
        }
        ++i;
      }
    }
    GlobalTypeRewriter rewriter(wasm);
    rewriter.mapTypes(oldToNew);
    rewriter.mapTypeNamesAndIndices(oldToNew);
  }
};

} // anonymous namespace

Pass* createMinimizeRecGroupsPass() { return new MinimizeRecGroups(); }

} // namespace wasm
