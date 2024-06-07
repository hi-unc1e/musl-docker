## muslrust + sccache

The `muslrust` image includes `sccache`, so you can use it easily to try to improve build times.

To use it, set `RUSTC_WRAPPER` to `path/to/sccache`, and set some environment variables to configure it.

* `SCCACHE_DIR` is the directory that sccache will use to cache build artifacts
* `SCCACHE_CACHE_SIZE` indicates the maximum size of the cache. `SCCACHE` will evict items when the limit is exceeded.
* `SCCACHE_ERROR_LOG` is a path to a text file, which you can inspect if there are errors.
* `CARGO_INCREMENTAL` should be set to `0` whenever using `sccache`. (modern versions of `sccache` may set this to 0 themselves, I'm not sure tbh.)

`sccache --show-stats` can be used to print stats for cache hits, misses etc. There is also an command to zero the stats,
but it is usually unnecessary to do so in the context of this image, because `sccache` does not persist the stats to disk,
and the process terminates when your build completes.

Here's an example `docker run` command:

```
if [ -z $MOUNT_ROOT ]; then
  MOUNT_ROOT="$HOME/.muslrust"
fi

POST_BUILD_CMD=chown -R $(id -u) ./target /root/.cargo/registry /root/sccache

docker run -v $PWD:/volume \
    -v "$MOUNT_ROOT/cargo/registry":/root/.cargo/registry \
    -v "$MOUNT_ROOT/sccache":/root/sccache \
    --env CARGO_INCREMENTAL=0 \
    --env RUSTC_WRAPPER=/usr/local/bin/sccache \
    --env SCCACHE_DIR=/root/sccache \
    --env SCCACHE_CACHE_SIZE="${SCCACHE_CACHE_SIZE:-5G}" \
    --env SCCACHE_ERROR_LOG=/tmp/sccache.log \
    --rm -t clux/muslrust:stable sh -c "AR=ar cargo build --release --locked && /usr/local/bin/sccache --show-stats && ${POST_BUILD_CMD}"
```

When you run this, you should see a report from sccache that looks something like the following:

```
    Finished `release` profile [optimized + debuginfo] target(s) in 2m 27s
Compile requests                    542
Compile requests executed           488
Cache hits                          484
Cache hits (C/C++)                   36
Cache hits (Rust)                   448
Cache misses                          1
Cache misses (Rust)                   1
Cache timeouts                        0
Cache read errors                     0
Forced recaches                       0
Cache write errors                    0
Compilation failures                  3
Cache errors                          0
Non-cacheable compilations            0
Non-cacheable calls                  52
Non-compilation calls                 2
Unsupported compiler calls            0
Average cache write               0.007 s
Average compiler                  1.568 s
Average cache read hit            0.002 s
Failed distributed compilations       0

Non-cacheable reasons:
unknown source language              24
crate-type                           22
-                                     5
-E                                    1

Cache location                  Local disk: "/root/sccache"
Use direct/preprocessor mode?   yes
Version (client)                0.8.0
Cache size                          494 MiB
Max cache size                       10 GiB
```

The above with a warm `sccache` cache, but a clean `target` directory. How many cache hits you get depends on many factors.
There are [a number of things you can do](https://github.com/mozilla/sccache?tab=readme-ov-file#known-caveats) to change your usage, or your rust code, to get more cache hits.

### Mounting and caching directories

In the above example, we're mounting `/root/.cargo/registry` and `/root/sccache` to the host machine, because these are directories we want to cache across invocations.

You could use docker named volumes instead of actually mounting them to the host filesystem if you like, but if you plan to use this in github actions,
it's better to actually mount them, and then cache those directories in github actions.

Note that if you are running this locally, neither of these directories is going to grow without bound, because `cargo` has a gc internally for registry stuff, and `sccache` evicts cached files
in an LRU fashion when the cache exceeds `SCCACHE_CACHE_SIZE`. So storing this in a home directory is a reasonably safe default.

Caching this correctly in github actions is pretty simple.

For "normal" rust builds (invoking cargo from gha directly, not using something like muslrust image or sccache), it's highly recommendable to use
something like the [`rust-cache` action](https://github.com/Swatinem/rust-cache) and not re-invent the wheel, beause that is going to do things like, try to cache all builds of dependencies intelligently,
check the toolchain and make that part of the cache key, etc. etc.

When using `muslrust` with `sccache`, `sccache` is essentially going to do all that work. The `SCCACHE_DIR` is safe to share across OS's, architectures, toolchains, etc, because all of that data goes
into the hash keys computed by `sccache`.
The `.cargo/registry` is also not dependent on your toolchain or OS or anything like that. Also `rust-cache` will attempt to figure out your `cargo` and `rustc` versions by interrogating whatever is in the path,
but that won't actually pick up the stuff in the `muslrust` image. So `rust-cache` is not the right choice here, and we can and should just use something very simple like

```
    - name: Cache muslrust cargo registry and sccache dir
      # https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows
      uses: actions/cache@v3
      with:
        path: /tmp/muslrust
        key: v1-sccache
        restore-keys: v1-sccache
```

and set `MOUNT_ROOT` to `/tmp/muslrust` in CI. (`$HOME` may or may not work correctly in gha).

The only reason to get fancier with the gha cache keys here is if you have lots of jobs using this and for some reason you don't expect them to be able to share artifacts.
For example, if you are using `muslrust:stable` and `muslrust:nightly`, probably nothing at all can be shared between these builds so you might as well use separate github cache keys for those.

Note that per docu, github has a repository limit of 10G in total for all caches created this way. I suggest using 5G as the `SCCACHE_CACHE_SIZE` and leaving some G's for the `.cargo/registry`, but ymmv.

### Post-build command

As described in the main [`README.md`](./README.md), on linux the build is going to run as root in the `muslrust` image and so any files it produces will be owned by root, if they are mounted into the container.
For several reasons that can become annoying, and a quick `chown` fixes it.

Here we're adding a `POST_BUILD_COMMAND` that changes ownership not only for the `target` directory, but also the cargo registry and sccache directories. This is because the github `actions/cache` action will fail
to save and restore files owned by root.

On a mac, docker works differently, so if you are using the example command there, the files won't actually be owned by root, and also the `chown` command will be very slow. So on mac it is better to either skip
the `POST_BUILD_CMD`, or you could modify it so that it actually tests if we are root before doing the `chown`.
