;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; git-lolevel.scm - libgit2 bindings for Chicken Scheme
;;
;; Copyright (c) 2011, Evan Hanson
;; See LICENSE for details
;;
;; Getting to be sort of complete.
;; Still, think twice before use.

(module git-lolevel *
  (import scheme lolevel foreign foreigners
    (except chicken repository-path))

;; Errors are composite conditions
;; of properties (exn git).
(define (git-error loc msg . args)
  (signal (make-composite-condition
            (make-property-condition 'git)
            (make-property-condition 'exn 'location  loc
                                          'message   msg))))

;; Check the return value of an expression,
;; signaling an error when nonzero.
(define-syntax guard-errors
  (syntax-rules ()
    ((_ <loc> <exp>)
     (let ((res <exp>))
       (if (< res 0) (git-error <loc> (lasterror)) res)))))

;; This could be compacted a bit more later, but for
;; right now we'll keep syntax-rules for readability.
(define-syntax define/allocate
  (syntax-rules ()
    ((_  <rtype> <name> (<cfun> (<atype> <arg>) ...))
     (define (<name> <arg> ...)
       (let-location ((object <rtype>))
         (guard-errors '<name>
           ((foreign-lambda int <cfun> (c-pointer <rtype>) <atype> ...)
              (location object) <arg> ...))
         object)))))

;; Same.
(define-syntax define/retval
  (syntax-rules ()
    ((_  <name> (<cfun> (<atype> <arg>) ...))
     (define (<name> <arg> ...)
       (if (not (guard-errors '<name>
                  ((foreign-lambda int <cfun> <atype> ...) <arg> ...)))
         #f))))) ;; Ignored, the if just forces a void return.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; git2.h

(foreign-declare "#include <git2.h>")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; types.h

(define-foreign-type time-t integer64)
(define-foreign-type off-t integer64)

(define-foreign-record-type (time git_time)
  (time-t time time-time)
  (int offset time-offset))

(define-foreign-record-type (signature git_signature)
  (c-string name signature-name)
  (c-string email signature-email)
  ((struct time) when signature-time))

(define-foreign-record-type (oid git_oid)
  (constructor: make-oid)
  (unsigned-char (id (foreign-value GIT_OID_RAWSZ int)) oid-id))

(define-foreign-record-type (index-time git_index_time)
  (time-t seconds index-time-seconds)
  (unsigned-int nanoseconds index-time-nanoseconds))

(define-foreign-record-type (index-entry git_index_entry)
  ((struct index-time) ctime index-entry-ctime)
  ((struct index-time) mtime index-entry-mtime)
  (unsigned-int dev index-entry-dev)
  (unsigned-int ino index-entry-ino)
  (unsigned-int mode index-entry-mode)
  (unsigned-int uid index-entry-uid)
  (unsigned-int gid index-entry-gid)
  (off-t file_size index-entry-size)
  ((struct oid) oid index-entry-oid)
  (unsigned-int flags index-entry-flags)
  (unsigned-int flags_extended index-entry-extended)
  (c-string path index-entry-path))

(define-foreign-record-type (index-entry-unmerged git_index_entry_unmerged)
  (unsigned-int (mode 3) index-entry-unmerged-mode)
  ((struct oid) (oid 3) index-entry-unmerged-oid)
  (c-string path index-entry-unmerged-path))

(define-foreign-type commit         (c-pointer "git_commit"))
(define-foreign-type config         (c-pointer "git_config"))
(define-foreign-type blob*          (c-pointer "git_blob")) ; clash w/ built-in
(define-foreign-type entry-unmerged (c-pointer "git_index_entry_unmerged"))
(define-foreign-type index          (c-pointer "git_index"))
(define-foreign-type object         (c-pointer "git_object"))
(define-foreign-type odb            (c-pointer "git_odb"))
(define-foreign-type odb-object     (c-pointer "git_odb_object"))
(define-foreign-type oid-shorten    (c-pointer "git_oid_shorten"))
(define-foreign-type reference      (c-pointer "git_reference"))
(define-foreign-type repository     (c-pointer "git_repository"))
(define-foreign-type revwalk        (c-pointer "git_revwalk"))
(define-foreign-type tag            (c-pointer "git_tag"))
(define-foreign-type tree           (c-pointer "git_tree"))
(define-foreign-type tree-entry     (c-pointer "git_tree_entry"))

(define-foreign-enum-type (otype int)
  (otype->int int->otype)
  ((any       otype/any)       GIT_OBJ_ANY)
  ((bad       otype/bad)       GIT_OBJ_BAD)
  ((ext1      otype/ext1)      GIT_OBJ__EXT1)
  ((commit    otype/commit)    GIT_OBJ_COMMIT)
  ((tree      otype/tree)      GIT_OBJ_TREE)
  ((blob      otype/blob)      GIT_OBJ_BLOB)
  ((tag       otype/tag)       GIT_OBJ_TAG)
  ((ext2      otype/ext2)      GIT_OBJ__EXT2)
  ((ofs-delta otype/ofs-delta) GIT_OBJ_OFS_DELTA)
  ((ref-delta otype/ref-delta) GIT_OBJ_REF_DELTA))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; blob.h

(define/allocate blob* blob*-lookup
  (git_blob_lookup (repository repo) (oid id)))

(define/allocate blob* blob*-lookup-prefix
  (git_blob_lookup_prefix (repository repo) (oid id) (unsigned-int len)))

(define blob*-close             (foreign-lambda void git_blob_close blob*))
(define blob*-rawcontent        (foreign-lambda c-string git_blob_rawcontent blob*))
(define blob*-rawsize           (foreign-lambda int git_blob_rawsize blob*))
(define blob*-create-fromfile   (foreign-lambda int git_blob_create_fromfile oid repository c-string))
(define blob*-create-frombuffer (foreign-lambda int git_blob_create_frombuffer oid repository c-string unsigned-int))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; commit.h

(define/allocate commit commit-lookup
  (git_commit_lookup (repository repo) (oid id)))

(define/allocate commit commit-lookup-prefix
  (git_commit_lookup_prefix (repository repo) (oid id) (unsigned-int len)))

(define commit-close         (foreign-lambda void git_commit_close commit))
(define commit-id            (foreign-lambda oid git_commit_id commit))
(define commit-message-short (foreign-lambda c-string git_commit_message_short commit))
(define commit-message       (foreign-lambda c-string git_commit_message commit))
(define commit-time          (foreign-lambda time-t git_commit_time commit))
(define commit-time-offset   (foreign-lambda int git_commit_time_offset commit))
(define commit-committer     (foreign-lambda signature git_commit_committer commit))
(define commit-author        (foreign-lambda signature git_commit_author commit))
(define commit-tree-oid      (foreign-lambda oid git_commit_tree_oid commit))
(define commit-parentcount   (foreign-lambda unsigned-int git_commit_parentcount commit))
(define commit-parent-oid    (foreign-lambda oid git_commit_parent_oid commit unsigned-int))

(define/allocate tree commit-tree (git_commit_tree (commit cmt)))
(define/allocate commit commit-parent (git_commit_parent (commit cmt) (unsigned-int n)))

(define (commit-create repo ref author commit msg tree . parents)
  (let ((id (make-oid)))
    (guard-errors commit-create
      ((foreign-lambda int git_commit_create_o
         oid repository c-string signature signature c-string tree int              pointer-vector)
         id  repo       ref      author    commit    msg      tree (length parents) (apply pointer-vector
                                                                                      (append parents #f))))
    id))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; common.h

(define-foreign-record-type (strarray git_strarray)
  (constructor: make-strarray)
  ((c-pointer c-string) strings %strarray-strings)
  (unsigned-int count strarray-count))

;; Not really needed, just here for completion's sake.
;; In fact using it will probably just result in a double-free.
(define strarray-free (foreign-lambda void git_strarray_free strarray))

;; Gets a GC'd list of strings from the strarray
;; (for return from e.g. git_reference_listall).
(define (strarray-strings sa)
  ((foreign-lambda* c-string-list* ((strarray sa))
     "char **s = (char **)malloc(sizeof(char **) * sa->count);
      memcpy(s, sa->strings, sizeof(char **) * sa->count);
      *(s + sa->count) = NULL;
      C_return(s);")
     sa))

(define (libgit2-version)
  (let-location ((major int) (minor int) (rev int))
    ((foreign-lambda void git_libgit2_version (c-pointer int) (c-pointer int) (c-pointer int))
       (location major)
       (location minor)
       (location rev))
    (vector major minor rev)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; config.h
;;
;; TODO

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; errors.h

(define-foreign-enum-type (err int)
  (err->int int->err)
  ((success             err/success)              GIT_SUCCESS)
  ((error               err/error)                GIT_ERROR)
  ((notoid              err/notoid)               GIT_ENOTOID)
  ((notfound            err/notfound)             GIT_ENOTFOUND)
  ((nomem               err/nomem)                GIT_ENOMEM)
  ((oserr               err/oserr)                GIT_EOSERR)
  ((objtype             err/objtype)              GIT_EOBJTYPE)
  ((notarepo            err/notarepo)             GIT_ENOTAREPO)
  ((invtype             err/invalidtype)          GIT_EINVALIDTYPE)
  ((missingobjdata      err/missingobjdata)       GIT_EMISSINGOBJDATA)
  ((packcorrupt         err/packcorrupt)          GIT_EPACKCORRUPTED)
  ((flockfail           err/flockfail)            GIT_EFLOCKFAIL)
  ((zlib                err/zlib)                 GIT_EZLIB)
  ((busy                err/busy)                 GIT_EBUSY)
  ((bareindex           err/bareindex)            GIT_EBAREINDEX)
  ((invrefname          err/invrefname)           GIT_EINVALIDREFNAME)
  ((refcorrupt          err/refcorrupt)           GIT_EREFCORRUPTED)
  ((toonestedsymref     err/toonestedsymref)      GIT_ETOONESTEDSYMREF)
  ((packedrefscorrupted err/packedrefscorrupted)  GIT_EPACKEDREFSCORRUPTED)
  ((invalidpath         err/invalidpath)          GIT_EINVALIDPATH)
  ((revwalkover         err/revwalkover)          GIT_EREVWALKOVER)
  ((invalidrefstate     err/invalidrefstate)      GIT_EINVALIDREFSTATE)
  ((notimplemented      err/notimplemented)       GIT_ENOTIMPLEMENTED)
  ((exists              err/exists)               GIT_EEXISTS)
  ((overflow            err/overflow)             GIT_EOVERFLOW)
  ((notnum              err/notnum)               GIT_ENOTNUM)
  ((stream              err/stream)               GIT_ESTREAM)
  ((invalidargs         err/invalidargs)          GIT_EINVALIDARGS)
  ((objcorrupted        err/objcorrupted)         GIT_EOBJCORRUPTED)
  ((ambiguousoidprefix  err/ambiguousoidprefix)   GIT_EAMBIGUOUSOIDPREFIX)
  ((passthrough         err/passthrough)          GIT_EPASSTHROUGH))

(define lasterror (foreign-lambda c-string git_lasterror))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; index.h

(define/allocate index index-open (git_index_open (c-string path)))

(define index-clear (foreign-lambda void git_index_clear index))
(define index-free  (foreign-lambda void git_index_free index))
(define index-find  (foreign-lambda int git_index_find index c-string))

(define/retval index-read   (git_index_read (index ix)))
(define/retval index-write  (git_index_write (index ix)))
(define/retval index-add    (git_index_add (index ix) (c-string path) (int stage)))
(define/retval index-append (git_index_append (index ix) (c-string path) (int stage)))
(define/retval index-remove (git_index_remove (index ix) (int pos)))

(define index-get                  (foreign-lambda index-entry git_index_get index unsigned-int))
(define index-entrycount           (foreign-lambda unsigned-int git_index_entrycount index))
(define index-entrycount-unmerged  (foreign-lambda unsigned-int git_index_entrycount_unmerged index))
(define index-get-unmerged-bypath  (foreign-lambda index-entry-unmerged git_index_get_unmerged_bypath index c-string))
(define index-get-unmerged-byindex (foreign-lambda index-entry-unmerged git_index_get_unmerged_byindex index unsigned-int))
(define index-entry-stage          (foreign-lambda int git_index_entry_stage index-entry))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; object.h

(define/allocate object object-lookup 
  (git_object_lookup (repository repo) (oid id) (otype type)))

(define object-id          (foreign-lambda oid git_object_id object))
(define object-close       (foreign-lambda void git_object_close object))
(define object-owner       (foreign-lambda repository git_object_owner object))
(define object-type        (foreign-lambda otype git_object_type object))
(define object-type2string (foreign-lambda otype git_object_type2string otype))
(define object-string2type (foreign-lambda otype git_object_string2type c-string))
(define object-typeisloose (foreign-lambda bool git_object_typeisloose otype))

;; Conflicts with built-in, and we don't really need it.
; (define object-size        (foreign-lambda size_t git_object__size otype))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; odb_backend.h
;;
;; TODO

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; odb.h
;;
;; TODO git_odb_add_backend git_odb_add_alternate git_odb_read_header
;;      git_odb_open_wstream git_odb_open_rstream

(define/allocate odb odb-new  (git_odb_new))
(define/allocate odb odb-open (git_odb_open (c-string dir)))

(define odb-close (foreign-lambda void git_odb_close odb))
(define odb-exists (foreign-lambda bool git_odb_exists odb oid))

(define/allocate odb-object odb-read
  (git_odb_read (odb db) (oid id)))

(define/allocate odb-object odb-read-prefix
  (git_odb_read_prefix (odb db) (oid id) (unsigned-int len)))

(define (odb-write db data len type)
  (let ((id (make-oid)))
    (guard-errors odb-write
      ((foreign-lambda int git_odb_write
         oid odb c-pointer            size_t otype)
         id  db  (make-locative data) len    type))
    id))

(define (odb-hash data len type)
  (let ((id (make-oid)))
    (guard-errors odb-hash
      ((foreign-lambda int git_odb_hash
         oid c-pointer            size_t otype)
         id  (make-locative data) len    type))
    id))

(define odb-object-close (foreign-lambda void git_odb_object_close odb-object))
(define odb-object-id    (foreign-lambda oid git_odb_object_id odb-object))
(define odb-object-data  (foreign-lambda c-pointer git_odb_object_data odb-object))
(define odb-object-size  (foreign-lambda size_t git_odb_object_size odb-object))
(define odb-object-type  (foreign-lambda otype git_odb_object_type odb-object))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; oid.h

(define (oid-fromstr str)
  (let ((id (make-oid)))
    (guard-errors oid-fromstr
      ((foreign-lambda int git_oid_fromstr oid c-string) id str))
    id))

(define (oid-fromraw raw)
  (let ((id (make-oid)))
    ((foreign-lambda void git_oid_fromraw oid blob) id raw)
    id))

(define (oid-fmt oid)
  (let* ((str (make-string 40))
         (loc (make-locative str)))
    ((foreign-lambda void git_oid_fmt (c-pointer char) oid) loc oid)
    str))

(define (oid-pathfmt oid)
  (let* ((str (make-string 40))
         (loc (make-locative str)))
    ((foreign-lambda void git_oid_pathfmt (c-pointer char) oid) loc oid)
    str))

(define oid-allocfmt     (foreign-lambda c-string git_oid_allocfmt oid))

(define (oid-to-string n id)
  (let* ((str (make-string n))
         (loc (make-locative str)))
    ((foreign-lambda c-string git_oid_to_string
       (c-pointer char) size_t  oid)
       loc              (+ n 1) id)))

(define oid-cpy          (foreign-lambda void git_oid_cpy oid oid))
(define oid-cmp          (foreign-lambda int git_oid_cmp oid oid))
(define oid-ncmp         (foreign-lambda int git_oid_ncmp oid oid unsigned-int))
(define oid-shorten-new  (foreign-lambda oid-shorten git_oid_shorten_new size_t))
(define oid-shorten-free (foreign-lambda void git_oid_shorten_free oid-shorten))

(define/retval oid-shorten-add
  (git_oid_shorten_add (oid-shorten osh) ((const c-string) oid)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; refs.h

(define-foreign-enum-type (rtype int)
  (rtype->int int->rtype)
  ((invalid  rtype/invalid)  GIT_REF_INVALID)
  ((oid      rtype/oid)      GIT_REF_OID)
  ((symbolic rtype/symbolic) GIT_REF_SYMBOLIC)
  ((packed   rtype/packed)   GIT_REF_PACKED)
  ((haspeel  rtype/haspeel)  GIT_REF_HAS_PEEL)
  ((listall  rtype/listall)  GIT_REF_LISTALL))

(define/allocate reference reference-lookup
  (git_reference_lookup (repository repo) (c-string name)))

(define/allocate reference reference-create-symbolic
  (git_reference_create_symbolic (repository repo) (c-string name) (c-string target)))

(define/allocate reference reference-create-symbolic-f
  (git_reference_create_symbolic_f (repository repo) (c-string name) (c-string target)))

(define/allocate reference reference-create-oid
  (git_reference_create_oid (repository repo) (c-string name) (oid id)))

(define/allocate reference reference-create-oid-f
  (git_reference_create_oid_f (repository repo) (c-string name) (oid id)))

(define reference-oid    (foreign-lambda oid git_reference_oid reference))
(define reference-target (foreign-lambda c-string git_reference_target reference))
(define reference-type   (foreign-lambda rtype git_reference_type reference))
(define reference-name   (foreign-lambda c-string git_reference_name reference))
(define reference-owner  (foreign-lambda repository git_reference_owner reference))

(define/allocate reference reference-resolve (git_reference_resolve (reference ref)))

(define/retval reference-set-target (git_reference_set_target (reference ref) (c-string target)))
(define/retval reference-set-oid    (git_reference_set_oid (reference ref) (oid id)))
(define/retval reference-rename     (git_reference_rename (reference ref) (c-string name)))
(define/retval reference-rename-f   (git_reference_rename_f (reference ref) (c-string name)))
(define/retval reference-delete     (git_reference_delete (reference ref)))
(define/retval reference-packall    (git_reference_packall (repository repo)))

(define (reference-listall repo flags)
  (let ((sa (make-strarray)))
    (guard-errors reference-listall
      ((foreign-lambda int git_reference_listall strarray repository rtype) sa repo flags))
    (strarray-strings sa)))

;; Maybe TODO foreach.
;; Probably not.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  
;; repository.h

(define-foreign-enum-type (path int)
  (path->int int->path)
  ((path path/path) GIT_REPO_PATH)
  ((index path/index) GIT_REPO_PATH_INDEX)
  ((odb path/odb) GIT_REPO_PATH_ODB)
  ((workdir path/workdir) GIT_REPO_PATH_WORKDIR))

(define/allocate repository repository-open
  (git_repository_open (c-string path)))

(define/allocate index repository-index
  (git_repository_index (repository repo)))

(define repository-database (foreign-lambda odb git_repository_database repository))
(define repository-free     (foreign-lambda void git_repository_free repository))
(define repository-is-empty (foreign-lambda bool git_repository_is_empty repository))
(define repository-is-bare  (foreign-lambda bool git_repository_is_bare repository))
(define repository-path     (foreign-lambda c-string git_repository_path repository path))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; revwalk.h

(define-foreign-enum-type (sort int)
  (sort->int int->sort)
  ((none sort/none) GIT_SORT_NONE)
  ((topo sort/topo) GIT_SORT_TOPOLOGICAL)
  ((time sort/time) GIT_SORT_TIME)
  ((rev sort/rev) GIT_SORT_REVERSE))

(define/allocate revwalk revwalk-new
  (git_revwalk_new (repository repo)))

(define revwalk-free        (foreign-lambda void git_revwalk_free revwalk))
(define revwalk-reset       (foreign-lambda void git_revwalk_reset revwalk))
(define revwalk-sorting     (foreign-lambda void git_revwalk_sorting revwalk sort))
(define revwalk-repository  (foreign-lambda repository git_revwalk_repository revwalk))
(define/retval revwalk-push (git_revwalk_push (revwalk wlk) (oid id)))
(define/retval revwalk-hide (git_revwalk_hide (revwalk wlk) (oid id)))

(define (revwalk-next walker)
  (let ((id (make-oid)))
    (guard-errors revwalk-next
      ((foreign-lambda int git_revwalk_next oid revwalk) id walker))
    id))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; signature.h

(define signature-new  (foreign-lambda signature git_signature_new c-string c-string time-t int))
(define signature-now  (foreign-lambda signature git_signature_now c-string c-string))
(define signature-dup  (foreign-lambda signature git_signature_dup signature))
(define signature-free (foreign-lambda void git_signature_free signature))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; tag.h

(define/allocate tag tag-lookup
  (git_tag_lookup (repository repo) (oid id)))

(define/allocate object tag-target
  (git_tag_target (tag t)))

(define tag-close      (foreign-lambda void git_tag_close tag))
(define tag-id         (foreign-lambda oid git_tag_id tag))
(define tag-target-oid (foreign-lambda oid git_tag_target_oid tag))
(define tag-type       (foreign-lambda otype git_tag_type tag))
(define tag-name       (foreign-lambda c-string git_tag_name tag))
(define tag-tagger     (foreign-lambda signature git_tag_tagger tag))
(define tag-message    (foreign-lambda c-string git_tag_message tag))

(define (tag-create repo name target tagger msg)
  (let ((id (make-oid)))
    (guard-errors tag-create
      ((foreign-lambda int git_tag_create_fo
         oid repository c-string object signature c-string)
         id  repo       name     target tagger    msg))
    id))

(define/retval tag-delete
  (git_tag_delete (repository repo) (c-string name)))

(define (tag-list repo)
  (let ((sa (make-strarray)))
    (guard-errors tag-list
      ((foreign-lambda int git_tag_list strarray repository) sa repo))
    (strarray-strings sa)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; tree.h

(define/allocate tree tree-lookup
  (git_tree_lookup (repository repo) (oid id)))

(define/allocate tree tree-lookup-prefix
  (git_tree_lookup_prefix (repository repo) (oid id) (unsigned-int len)))

(define tree-close            (foreign-lambda void git_tree_close tree))
(define tree-id               (foreign-lambda oid git_tree_id tree))
(define tree-entrycount       (foreign-lambda unsigned-int git_tree_entrycount tree))
(define tree-entry-byname     (foreign-lambda tree-entry git_tree_entry_byname tree c-string))
(define tree-entry-byindex    (foreign-lambda tree-entry git_tree_entry_byindex tree unsigned-int))
(define tree-entry-attributes (foreign-lambda unsigned-int git_tree_entry_attributes tree-entry))
(define tree-entry-name       (foreign-lambda c-string git_tree_entry_name tree-entry))
(define tree-entry-id         (foreign-lambda oid git_tree_entry_id tree-entry))
(define tree-entry-type       (foreign-lambda otype git_tree_entry_type tree-entry))

(define/allocate object tree-entry-2object
  (git_tree_entry_2object (repository repo) (tree-entry entry)))

(define (tree-create-fromindex ix)
  (let ((id (make-oid)))
    (guard-errors tree-create-fromindex
      ((foreign-lambda int git_tree_create_fromindex oid index) id ix))
    id)))

;; TODO treebuilders
