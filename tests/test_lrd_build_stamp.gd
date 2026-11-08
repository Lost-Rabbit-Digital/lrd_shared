extends GdUnitTestSuite

const GIT: String = "user://test_lrd_git/"
const SHA: String = "0123456789abcdef0123456789abcdef01234567"
## A linked worktree: `.git` is a file naming its own git dir, which holds HEAD,
## while branch refs live in the main repo's git dir (`commondir`).
const WORKTREE: String = "user://test_lrd_worktree/"
const MAIN_GIT: String = "user://test_lrd_worktree_main/.git/"

var _previous_git_dir: String


func before_test() -> void:
	_previous_git_dir = LRDBuildStamp.git_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GIT + "refs/heads"))
	LRDBuildStamp.git_dir = GIT
	LRDBuildStamp.reset_cache()


func after_test() -> void:
	for file: String in ["HEAD", "packed-refs", "refs/heads/main"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GIT + file))
	for file: String in [
		WORKTREE + ".git",
		MAIN_GIT + "worktrees/wt/HEAD",
		MAIN_GIT + "worktrees/wt/commondir",
		MAIN_GIT + "refs/heads/feature",
		MAIN_GIT + "packed-refs",
	]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	LRDBuildStamp.git_dir = _previous_git_dir
	LRDBuildStamp.reset_cache()


func _write(path: String, text: String) -> void:
	_write_at(GIT + path, text)


func _write_at(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_version_comes_from_the_project() -> void:
	assert_str(LRDBuildStamp.version()).is_equal(str(ProjectSettings.get_setting("application/config/version")))


func test_a_branch_head_reads_its_loose_ref() -> void:
	_write("HEAD", "ref: refs/heads/main\n")
	_write("refs/heads/main", SHA + "\n")
	assert_str(LRDBuildStamp.commit()).is_equal(SHA)


func test_a_packed_ref_is_found() -> void:
	_write("HEAD", "ref: refs/heads/main\n")
	_write("packed-refs", "# pack-refs with: peeled fully-peeled sorted\n%s refs/heads/main\n" % SHA)
	assert_str(LRDBuildStamp.commit()).is_equal(SHA)


func test_a_detached_head_is_the_sha() -> void:
	_write("HEAD", SHA + "\n")
	assert_str(LRDBuildStamp.commit()).is_equal(SHA)


func test_describe_is_version_plus_short_sha() -> void:
	_write("HEAD", SHA + "\n")
	assert_str(LRDBuildStamp.describe()).is_equal(LRDBuildStamp.version() + "+0123456")


func test_no_git_means_the_version_alone() -> void:
	LRDBuildStamp.git_dir = "user://test_lrd_no_git_here/"
	assert_str(LRDBuildStamp.commit()).is_equal(LRDBuildStamp.UNKNOWN)
	assert_str(LRDBuildStamp.describe()).is_equal(LRDBuildStamp.version())


## Every studio agent works in a linked worktree (and a game can be a
## submodule), where `.git` is a file, not a directory. Rows written there
## carried no sha, so every worktree run grouped under the bare version.
func _make_worktree() -> void:
	var main_git_abs: String = ProjectSettings.globalize_path(MAIN_GIT)
	_write_at(WORKTREE + ".git", "gitdir: %sworktrees/wt\n" % main_git_abs)
	_write_at(MAIN_GIT + "worktrees/wt/HEAD", "ref: refs/heads/feature\n")
	_write_at(MAIN_GIT + "worktrees/wt/commondir", "../..\n")
	LRDBuildStamp.git_dir = WORKTREE + ".git/"


func test_a_worktree_reads_its_head_and_the_shared_loose_ref() -> void:
	_make_worktree()
	_write_at(MAIN_GIT + "refs/heads/feature", SHA + "\n")
	assert_str(LRDBuildStamp.commit()).is_equal(SHA)


func test_a_worktree_finds_a_packed_ref_in_the_main_repo() -> void:
	_make_worktree()
	_write_at(MAIN_GIT + "packed-refs", "%s refs/heads/feature\n" % SHA)
	assert_str(LRDBuildStamp.commit()).is_equal(SHA)


func test_a_relative_gitdir_is_resolved_against_the_worktree() -> void:
	_make_worktree()
	_write_at(WORKTREE + ".git", "gitdir: ../test_lrd_worktree_main/.git/worktrees/wt\n")
	_write_at(MAIN_GIT + "refs/heads/feature", SHA + "\n")
	assert_str(LRDBuildStamp.commit()).is_equal(SHA)
