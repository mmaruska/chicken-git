;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; git-lolevel.scm - libgit2 bindings for Chicken Scheme
;;
;; Copyright (c) 2011, Evan Hanson
;; See LICENSE for details
;;
;; Nowhere near complete. Don't use this.

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

;; Check retval, signal an error when nonzero.
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
       (guard-errors '<name>
         ((foreign-lambda int <cfun> <atype> ...) <arg> ...))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; git2.h

(foreign-declare "#include <git2.h>")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; types.h

(define-foreign-type commit         (c-pointer "git_commit"))
(define-foreign-type config         (c-pointer "git_config"))
(define-foreign-type blob*          (c-pointer "git_blob")) ; clash w/ built-in
(define-foreign-type entry          (c-pointer "git_index_entry"))
(define-foreign-type entry-unmerged (c-pointer "git_index_entry_unmerged"))
(define-foreign-type index          (c-pointer "git_index"))
(define-foreign-type object         (c-pointer "git_object"))
(define-foreign-type odb            (c-pointer "git_odb"))
(define-foreign-type oid            (c-pointer "git_oid"))
(define-foreign-type reference      (c-pointer "git_reference"))
(define-foreign-type repository     (c-pointer "git_repository"))
(define-foreign-type revwalk        (c-pointer "git_revwalk"))
(define-foreign-type signature      (c-pointer "git_signature"))
(define-foreign-type time           (c-pointer "git_time_t"))
(define-foreign-type tree           (c-pointer "git_tree"))

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

(define/allocate blob* blob-lookup
  (git_blob_lookup (repository repo) (oid id)))

(define/allocate blob* blob-lookup-prefix
  (git_blob_lookup_prefix (repository repo) (oid id) (unsigned-int len)))

(define blob-close             (foreign-lambda void git_blob_close blob*))
(define blob-rawcontent        (foreign-lambda c-pointer git_blob_rawcontent blob*))
(define blob-rawsize           (foreign-lambda int git_blob_rawsize blob*))
(define blob-create-fromfile   (foreign-lambda int git_blob_create_fromfile oid repository c-string))
(define blob-create-frombuffer (foreign-lambda int git_blob_create_frombuffer oid repository c-string unsigned-int))

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
(define commit-time          (foreign-lambda time git_commit_time commit))
(define commit-time-offset   (foreign-lambda int git_commit_time_offset commit))
(define commit-committer     (foreign-lambda signature git_commit_committer commit))
(define commit-author        (foreign-lambda signature git_commit_author commit))

(define/allocate tree commit-tree
  (git_commit_tree (commit cmt)))

(define commit-tree-oid      (foreign-lambda oid git_commit_tree_oid commit))
(define commit-parentcount   (foreign-lambda unsigned-int git_commit_parentcount commit))

(define/allocate commit commit-parent
  (git_commit_parent (commit cmt) (unsigned-int n)))

(define commit-parent-oid    (foreign-lambda oid git_commit_parent_oid commit unsigned-int))

(define (commit-create id repo ref aut cmt msg tree pc par)
  (let ((id (allocate (foreign-value "sizeof(git_oid)" int))))
    (guard-errors commit-create
      ((foreign-lambda int git_commit_create
         oid repository c-string signature signature c-string oid  int (const (c-pointer oid)))
         id  repo       ref      aut       cmt       msg      tree pc  par))
    id))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; common.h

(define (libgit2-version)
  (let-location ((major int) (minor int) (rev int))
    ((foreign-lambda void git_libgit2_version (c-pointer int) (c-pointer int) (c-pointer int))
       (location major)
       (location minor)
       (location rev))
    (values major minor rev)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; config.h
;;
;; TODO

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; errors.h

;; Maybe TODO bind git_error enum.
;; git_lasterror gives us nice enough access to error messages for now.

(define lasterror (foreign-lambda c-string git_lasterror))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; index.h

;; TODO Lots of these follow the same pattern, should be unified.

(define/allocate index index-open
  (git_index_open (c-string path)))

(define index-clear (foreign-lambda void git_index_clear index))
(define index-free  (foreign-lambda void git_index_free index))

(define/retval index-read  (git_index_read (index ix)))
(define/retval index-write (git_index_write (index ix)))

(define index-find (foreign-lambda int index_find c-string))

(define/retval index-add    (git_index_add (index ix) (c-string path) (int stage)))
(define/retval index-append (git_index_append (index ix) (c-string path) (int stage)))
(define/retval index-remove (git_index_remove (index ix) (int pos)))

(define index-get                  (foreign-lambda entry git_index_get index unsigned-int))
(define index-entrycount           (foreign-lambda unsigned-int git_index_entrycount index))
(define index-entrycount-unmerged  (foreign-lambda unsigned-int git_index_entrycount_unmerged index))
(define index-get-unmerged-bypath  (foreign-lambda entry-unmerged git_index_get_unmerged_bypath index c-string))
(define index-get-unmerged-byindex (foreign-lambda entry-unmerged git_index_get_unmerged_byindex index unsigned-int))
(define index-entry-stage          (foreign-lambda int git_index_entry_stage entry))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; object.h

(define/allocate object object-lookup 
  (git_object_lookup (repository repo) (oid id) (obj type)))

(define object-id          (foreign-lambda oid git_object_id object))
(define object-close       (foreign-lambda void git_object_close object))
(define object-owner       (foreign-lambda repository git_object_owner object))
(define object-type        (foreign-lambda otype git_object_type object))
(define object-type2string (foreign-lambda otype git_object_type2string obj))
(define object-string2type (foreign-lambda otype git_object_string2type c-string))
(define object-typeisloose (foreign-lambda bool git_object_typeisloose otype))
(define object-size        (foreign-lambda unsigned-int git_object__size otype))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; odb_backend.h
;;
;; TODO

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; odb.h
;;
;; TODO

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; oid.h

(define (oid-fromstr str)
  (let ((id (allocate (foreign-value "sizeof(git_oid)" int))))
    (guard-errors oid-fromstr
      ((foreign-lambda int git_oid_fromstr oid c-string) id str))
    id))

(define (oid-fromraw raw)
  (let ((id (allocate (foreign-value "sizeof(git_oid)" int))))
    ((foreign-lambda void git_oid_fromraw oid blob) id raw)
    id))

;; TODO

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

(define/allocate reference reference-resolve
  (git_reference_resolve (reference ref)))

(define reference-owner  (foreign-lambda repository git_reference_owner reference))

(define/retval reference-set-target (git_reference_set_target (reference ref) (c-string target)))
(define/retval reference-set-oid    (git_reference_set_oid (reference ref) (oid id)))
(define/retval reference-rename     (git_reference_rename (reference ref) (c-string name)))
(define/retval reference-rename-f   (git_reference_rename_f (reference ref) (c-string name)))
(define/retval reference-delete     (git_reference_delete (reference ref)))
(define/retval reference-packall    (git_reference_packall (repository repo)))

;; TODO

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

(define repository-database
  (foreign-lambda odb git_repository_database repository))

(define/allocate index repository-index
  (git_repository_index (repository repo)))

(define repository-free
  (foreign-lambda void git_repository_free repository))

(define repository-is-empty
  (foreign-lambda bool git_repository_is_empty repository))

(define repository-is-bare
  (foreign-lambda bool git_repository_is_bare repository))

(define repository-path
  (foreign-lambda c-string git_repository_path repository path))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; revwalk.h

(define/allocate revwalk revwalk-new
  (git_revwalk_new (repository repo)))

(define revwalk-push
  (foreign-lambda int git_revwalk_push revwalk oid))

(define (revwalk-next walker)
  (let ((id (allocate (foreign-value "sizeof(git_oid)" int))))
    ((foreign-lambda int git_revwalk_next oid revwalk) id walker)
    id))

(define revwalk-free
  (foreign-lambda void git_revwalk_free revwalk)))
