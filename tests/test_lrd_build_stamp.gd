extends GdUnitTestSuite

const GIT: String = "user://test_lrd_git/"
const SHA: String = "0123456789abcdef0123456789abcdef01234567"

var _previous_git_dir: String


func before_test() -> void:
	_previous_git_dir = LRDBuildStamp.git_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GIT + "refs/heads"))
	LRDBuildStamp.git_dir = GIT
	LRDBuildStamp.reset_cache()


func after_test() -> void:
	for file: String in ["HEAD", "packed-refs", "refs/heads/main"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GIT + file))
	LRDBuildStamp.git_dir = _previous_git_dir
	LRDBuildStamp.reset_cache()


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(GIT + path, FileAccess.WRITE)
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
