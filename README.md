# Super Guppy

**Private Cargo registries using Tailscale and Fly.io.**

Super Guppy is a turnkey Docker image that makes it easy to run your own
[alternate Cargo registry][altcargo], with [Ktra][ktra] as the alternate Cargo
registry server. Security and authorization is provided by
[Tailscale][tailscale]. Any Docker-aware hosting provider should work (even your
own machine), but Super Guppy is primarily tested with Fly.io and Docker
Desktop.

[altcargo]:
    https://doc.rust-lang.org/cargo/reference/registries.html#using-an-alternate-registry
[ktra]: https://github.com/moriturus/ktra
[tailscale]: https://tailscale.com/
