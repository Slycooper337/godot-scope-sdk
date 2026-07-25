class_name ScopeStorage
extends RefCounted
var _api: ScopeAPI
func _init(api: ScopeAPI) -> void: _api = api
func upload(file_path: String, metadata: Dictionary = {}) -> ScopeResponse:
	var result := await _api.request_multipart_file("/storage/files", file_path, metadata)
	if result.success: result.data = ScopeStorageFile.from_json(result.data)
	return result
func info(file_id: int) -> ScopeResponse:
	var result := await _api.request_get("/storage/files/%d/info" % file_id)
	if result.success: result.data = ScopeStorageFile.from_json(result.data)
	return result
func download(file_id: int, destination_path: String = "") -> ScopeResponse:
	var result := await _api.request_bytes("/storage/files/%d" % file_id)
	if not result.success: return result
	if destination_path.is_empty(): return result
	var file := FileAccess.open(destination_path, FileAccess.WRITE)
	if file == null: return ScopeResponse.fail(0, "Could not open download destination")
	file.store_buffer(result.data); result.data = destination_path
	return result
func delete(file_id: int) -> ScopeResponse: return await _api.request_delete("/storage/files/%d" % file_id)
