import { fetchRemoteEnvironmentDescriptor } from "@t3tools/client-runtime/environment";
import type { EnvironmentId } from "@t3tools/contracts";
import * as Option from "effect/Option";
import { useEffect, useMemo, useState } from "react";

import { remoteHttpRuntime } from "../lib/runtime";
import { appAtomRegistry } from "../rpc/atomRegistry";
import { environmentSession } from "./session";

// Fork-local (i7hq). Descriptor state dirs fetched straight from each
// environment's well-known metadata endpoint. Fetched end-to-end through the
// tunnel, so a fork-added descriptor field survives even when the upstream
// relay would strip it from its own status responses. A successful fetch is
// cached for the session (including "server too old, no stateDir" as null);
// a failed fetch is retried the next time a consumer mounts.
const stateDirCache = new Map<EnvironmentId, string | null>();
const pendingFetches = new Set<EnvironmentId>();

/**
 * State directories for the given (non-primary) environments, keyed by
 * environment id. Environments still connecting, still fetching, or running
 * a pre-stateDir server are simply absent from the result.
 *
 * The prepared connection arrives over a stream-backed atom, so this
 * subscribes (keeping the atom mounted) rather than doing a one-shot registry
 * read that would only ever observe the initial `Option.none()`.
 */
export function useEnvironmentStateDirs(
  environmentIds: ReadonlyArray<EnvironmentId>,
  enabled: boolean,
): ReadonlyMap<EnvironmentId, string> {
  const [fetchCount, setFetchCount] = useState(0);

  useEffect(() => {
    if (!enabled) {
      return;
    }
    const unsubscribes: Array<() => void> = [];
    for (const environmentId of environmentIds) {
      if (stateDirCache.has(environmentId) || pendingFetches.has(environmentId)) {
        continue;
      }
      const unsubscribe = appAtomRegistry.subscribe(
        environmentSession.preparedConnectionValueAtom(environmentId),
        (prepared) => {
          if (Option.isNone(prepared)) {
            return;
          }
          if (stateDirCache.has(environmentId) || pendingFetches.has(environmentId)) {
            return;
          }
          pendingFetches.add(environmentId);
          remoteHttpRuntime
            .runPromise(
              fetchRemoteEnvironmentDescriptor({ httpBaseUrl: prepared.value.httpBaseUrl }),
            )
            .then(
              (descriptor) => {
                pendingFetches.delete(environmentId);
                if (descriptor.environmentId !== environmentId) {
                  return;
                }
                stateDirCache.set(environmentId, descriptor.stateDir ?? null);
                setFetchCount((count) => count + 1);
              },
              () => {
                pendingFetches.delete(environmentId);
              },
            );
        },
        { immediate: true },
      );
      unsubscribes.push(unsubscribe);
    }
    return () => {
      for (const unsubscribe of unsubscribes) {
        unsubscribe();
      }
    };
  }, [enabled, environmentIds]);

  return useMemo(() => {
    void fetchCount;
    const result = new Map<EnvironmentId, string>();
    if (!enabled) {
      return result;
    }
    for (const environmentId of environmentIds) {
      const stateDir = stateDirCache.get(environmentId);
      if (typeof stateDir === "string") {
        result.set(environmentId, stateDir);
      }
    }
    return result;
  }, [enabled, environmentIds, fetchCount]);
}
