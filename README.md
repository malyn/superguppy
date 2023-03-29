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

## Setup Instructions

The Super Guppy image is entirely self-contained, and configured exclusively
through environment variables. Git repository initialization is handled
automatically, and Tailscale login is performed using the web link flow.
Familiarizing yourself with the [Ktra book][ktrabook] might be helpful, and
reading [fasterthanlime's article on private Cargo registries][ftlregistry] will
provide some context on the approach used by Super Guppy. Most of the process is
automated by Super Guppy, however, with only [Ktra user creation and
login][ktrausers] unchanged from the normal Ktra flow.

The steps below take you through the initial deployment process on Fly.io, and
demonstrate creating a single Ktra user.

[ftlregistry]:
    https://fasterthanli.me/articles/my-ideal-rust-workflow#private-crate-registries
[ktrabook]: https://book.ktra.dev/
[ktrausers]: https://book.ktra.dev/quick_start/create_user_and_login.html

### Create Tailscale ACL Tag

There are a number of ways to protect access to the private Cargo registry. The
simplest approach is to limit access to all Tailscale "members" (in other words,
normal user accounts) and then any tagged devices that are not considered
members. The latter covers ephemeral keys for CI systems like GitHub Actions.

The example in this section takes that approach: all members can access the
registry, as well as the `github` tag (which is assumed to be the tag you use
for your GitHub Actions). Note that this action assumes that you set the
`PRIVATE_REPO_HOSTNAME` to `crates`, per the example later on in these setup
directions.

All of these steps are performed in the
[Tailscale Access Controls](https://login.tailscale.com/admin/acls) console.

1. Add a new tag to the `tagOwners` list for GitHub Actions:

    ```jsonc
    // ACL tags.
    "tagOwners": {
        "tag:github": [],
    },
    ```

2. Add a section for the `crates` machine to the `acls` block:

    ```jsonc
    "acls": [
        // ...

        // All users, and GitHub Actions, can access the private Cargo registry.
    	{
    		"action": "accept",
    		"src":    ["autogroup:members", "tag:github"],
    		"dst":    ["crates:80"],
    	},

        // ...
    ],
    ```

3. (Optionally) Add an ACL test to verify that `github` can access the Cargo
   registry, but not any other ports (such as SSH):

    ```jsonc
     "acls": [
        // ...

        // GitHub can access the cargo registry (but not SSH).
        {
            "src":    "tag:github",
            "accept": ["crates:80"],
            "deny":   ["crates:22"],
        },

        // ...
     ],
    ```

### Deploy the Super Guppy App to Fly.io

Launch (but do not deploy) the Fly.io app, and then create a volume for the app
(adjust the size as necessary):

```shell
$ flyctl launch --build-only --no-deploy --image ghcr.io/malyn/superguppy:latest
$ flyctl volumes create crates_data --size 1
```

You can choose an app name, or go with the auto-generated default. The app name
will not be used, as the machine will only be accessed via Tailscale using the
`PRIVATE_REPO_HOSTNAME`.

Modify the generated `fly.toml` file to add the `PRIVATE_REPO_HOSTNAME` and
mount the volume that you just created:

```toml
# ...

[env]
  PRIVATE_REPO_HOSTNAME = "crates"

[mounts]
  source="crates_data"
  destination="/data"

# ...
```

Note that the application does not need -- and in fact _should not have_ -- a
public IP address! The only access to the application is via Tailscale. Delete
the entire `[[services]]` section from the generated `fly.toml` file. Your
`fly.toml` file should look similar to this (but with your private `app` name):

```toml
app = "superguppy"
kill_signal = "SIGINT"
kill_timeout = 5
primary_region = "lax"
processes = []

[build]
  image = "ghcr.io/malyn/superguppy:latest"

[env]
  PRIVATE_REPO_HOSTNAME = "crates"

[mounts]
  source="crates_data"
  destination="/data"
```

Now launch the app:

```shell
$ flyctl deploy
```

Note that you _must_ watch the deployment logs (in the Monitoring tab of the
Fly.io dashboard) so that you can join the node to Tailscale during the initial
startup procedure:

```
tailscale-up[pre]: To authenticate, visit:
tailscale-up[pre]:
tailscale-up[pre]: https://login.tailscale.com/a/randomhexetc
tailscale-up[pre]:
```

Click on that URL to authorize the node and join it to your Tailnet. You may
want to disable expiry on that node in Tailscale in order to avoid the need to
(manually) re-auth when the key expires.

## Adding Users to Ktra

Follow the [instructions in the Ktra book][ktrausers] to add users to your
private registry. Here is a quick example to get you started:

```shell
$ curl -X POST -H 'Content-Type: application/json' -d '{"password":"INSERTPASSWORDHERE"}' http://crates.my-tailnet-name.ts.net/ktra/api/v1/new_user/insertusernamehere
{"token":"yourrandomtokenappearsrighthere"}
```

Then, in a project where you intend to use the private registry, make sure that
your `.cargo/config.toml` includes the name and URL for the registry:

```toml
[registries]
mysecretregistry = { index = "http://crates.my-tailnet-name.ts.net/git/index" }
```

You can then login to the registry using the token printed earlier:

```shell
$ cargo login --registry=mysecretregistry yourrandomtokenappearsrighthere
```
