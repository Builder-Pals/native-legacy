# Client-side cloning

This document records the design constraints around the `net_copy` patch. Read it before changing client-side `Instance:Clone()`, pooled instances, defiltering property order, or joint reconstruction.

## Purpose

Before `FilteringEnabled`, instances cloned by a client could replicate to the server. Native Legacy emulates that behavior by claiming server-created instances from a client pool and reconstructing the clone graph on both sides.

The primary implementation is in:

- `src/systems/default/Instance/net_cloning/init.luau`
- `src/systems/default/Instance/network_properties.luau`
- `src/sandbox/pool/client_pool.luau`
- `src/sandbox/defiltering/defilterer_client.luau`
- `src/sandbox/defiltering/defilter_serdes.luau`
- `src/sandbox/defiltering/defilterer_server.luau`
- `src/network/net_locker.luau`

## Clone construction phases

`net_copy` reconstructs a clone in this order:

1. Collect the Archivable source graph.
2. Claim every pooled identity before resolving references.
3. Apply modified scalar properties and metadata.
4. Remap Instance-valued properties after every counterpart exists.
5. Rebuild the hierarchy while the root remains staged.
6. Queue script filling.
7. Return the root. A caller may then assign its final `Parent`.

Do not collapse or reorder these phases. Physical joints can activate as soon as their endpoints and ancestry are valid. Applying a weld before cloned parts have their correct transforms can move an existing source assembly when the weld retains an external endpoint.

## Defiltering order is an invariant

Local clone construction was historically ordered, but the defilterer used nested hash maps. Iterating those maps discarded the construction order before applying properties on the server.

The defilterer now stores an ordered operation log. Repeated writes to the same instance/property invalidate the older operation and append the newest one. This provides both:

- one transmitted value per instance/property in a flush; and
- ordering based on the last write.

Serialization may combine consecutive operations for the same instance, but deserialization must process chunks and their properties forwards. The intended server order is:

```text
pool claims -> scalar properties/transforms -> references -> hierarchy/script fill -> caller's final Parent
```

This ordering is shared infrastructure, not merely an optimization for cloning. Do not convert it back to a map or reverse property traversal.

Large clones may yield while waiting for pool expansion. This is safe because all identities are claimed before property reconstruction begins; early flushes contain only staging claims. Avoid introducing yields after property reconstruction starts unless clone operations gain an explicit transaction boundary.

## Legacy Snap exception

Legacy cloning omitted a `Snap` descendant when either non-nil endpoint was outside the graph being cloned. Native Legacy intentionally preserves this exception.

The test must use membership in the actual Archivable graph, not only `IsDescendantOf(root)`. In particular:

- the root itself is an internal endpoint;
- a descendant excluded through `Archivable = false` is not in the clone graph; and
- descendants of an omitted external `Snap` must also be omitted so no orphaned clone nodes remain.

Do not generalize this rule to all joints. External references on `Weld`, `ManualWeld`, `Motor6D`, `WeldConstraint`, constraints, `ObjectValue`, and other Instance properties currently retain the original reference through:

```luau
copy_for[source_reference] or source_reference
```

That retention is a compatibility decision. If a caller later moves a clone whose weld still connects to an outside/source part, Roblox may move the connected source assembly. That is distinct from the construction-order bug: merely creating and exposing a correctly positioned clone must not move the source.

## Symbolic defiltering properties

The server defilterer recognizes properties that are transport commands rather than Roblox properties:

- `__r`: set `Parent` to `nil`
- `__d`: destroy the instance
- `__a:<name>`: set an attribute
- `__t:<tag>`: add a tag
- `__s`: fill a cloned script from the supplied original script

Script fill is deliberately sent through the ordered property stream. Sending it immediately on a separate remote lets it overtake queued clone properties. The older `request_script_fill` server handler remains as a compatibility path, but new clone construction should use `__s`.

Properties with a `__` prefix are ignored by the acknowledgement locker because they are commands rather than locally writable engine properties.

## Local prediction and locks

`network_properties.net_set` and `net_set_unlocked` update the local instance immediately and then enqueue replication.

- Use `net_set` for ordinary predicted writes that need an acknowledgement lock.
- Use `net_set_unlocked` for construction-time writes. It cancels an older lock for the property and avoids creating hundreds of clone locks.

The client pool represents a clone root with legacy-visible `Parent == nil` while its server-backed identity is staged under `replicated_nil`. Keep the `staged_parent` getter patch aligned with this behavior.

## Failure and cleanup

Clone reconstruction is wrapped in `xpcall`. If any phase fails, every claimed copy must be discarded in reverse reservation order. Reverse cleanup prevents parent destruction from cascading through child identities that still have queued rollback work.

Do not return a partially built graph. Do not expose the root before all descendant parenting and internal references have been queued.

## Review checklist

When modifying this system, verify all of the following:

- `Archivable = false` on the root returns `nil` without claiming instances.
- Non-Archivable subtrees are absent from the result.
- Internal Instance references point to their cloned counterparts.
- External non-`Snap` references still point to their originals.
- External `Snap` descendants are absent.
- A `Snap` referencing the cloned root is not incorrectly considered external.
- Scalar transforms arrive before joint endpoint references.
- Descendant hierarchy arrives before the caller's final root `Parent`.
- Repeated writes transmit only their newest value at their newest position.
- Scripts are filled after their clone properties/hierarchy are queued.
- Attributes and tags survive cloning.
- An error discards every claimed pooled instance.

## Suggested runtime regression model

Use a model containing at least six unanchored parts joined in a chain, rather than a single block. Include:

1. several internal `Weld`s;
2. an intentionally external `Weld` endpoint;
3. an external `Snap`, which should be omitted; and
4. optionally a non-Archivable descendant referenced by a joint.

Record the source pivot and external part position, clone and parent the model without repositioning it, wait for server application, and assert that both deltas are zero. Also assert that internal weld endpoints target copies, the external `Weld` endpoint targets the original outside part, and the external `Snap` is absent.

Then test the expected caveat separately: repositioning a clone after parenting it while an external weld is still connected may move the source assembly.

For static validation, run:

```powershell
git diff --check
rojo build default.project.json --output $env:TEMP\native-legacy-clone-check.rbxlx
```

Darklua can be used to parse changed Luau files when a dedicated type checker is unavailable. A Studio command-bar test cannot initialize the full sandbox unless the normal loader has already bootstrapped the client-side `replicated_nil` transport; treat that setup failure separately from clone behavior.
