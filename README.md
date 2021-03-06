# chicken-git

libgit2 bindings for Chicken Scheme.

## Install

Obviously, libgit2 is required: <http://github.com/libgit2/>.

Assuming you have that, installation should be straightforward:

    $ git clone git://github.com/evhan/chicken-git.git
    $ cd chicken-git
    $ chicken-install -test

This library requires libgit2 0.17.0 and Chicken 4.7 or newer.

## API

The library is split into two modules, `git` and `git-lolevel`:

* `git-lolevel` is essentially just the libgit2 API, thinly wrapped. Most of
  the function signatures remain the same, with a few exceptions: 

  * Structures & pointers that would go on the stack are allocated
    automatically.
  * Return values are checked where appropriate, signaling an exception of type
    'git when negative.
  * Pointer arrays are converted to rest arguments.

* `git` is a higher-level interface around `git-lolevel`, providing
  record types for each libgit2 structure.

Documentation is available at <http://wiki.call-cc.org/egg/git>.

## Notes

Some functionality is not yet provided, such as custom backends, remotes and
reflog inspection. Obviously, patches are more than welcome.

## Contact

  * Evan Hanson <evhan@thunktastic.com>

## License

BSD. See LICENSE for details.
