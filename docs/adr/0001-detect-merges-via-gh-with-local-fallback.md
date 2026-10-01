# Detect merged branches via gh, with local fallbacks

Originally, a per-branch area was offered for promotion only once its local branch was deleted ("gone"), deliberately avoiding merge detection so it behaved the same under squash merges and needed no network. That meant merged work was not offered for promotion until the branch was cleaned up, and a branch deleted while its PR was still open was reported every session. We now detect merged branches: `hook-start` and `status` make one `gh pr list` call against the trunk (with a short timeout) to sort each area as merged, PR open, or PR closed. When `gh` is unavailable or fails, we fall back to local ancestry and patch-id checks against `origin/<trunk>` (no fetch), and finally to the original "gone" rule, so working offline or off GitHub is never worse than before.

## Considered Options

- **Local only (ancestry + patch-id):** no network, but misses squash merges, the common case on GitHub, so it adds little.
- **Fetch before checking:** fresher refs, but puts a network round-trip in every session start; `gh` already answers for the main path.
- **Automatic promote on merge:** rejected for now. Promote assigns `NNNN-` numbers that are hard to take back once referenced, so a wrong detection would make unshipped proposals look accepted. Detection only changes what the agent recommends; the user still decides.
