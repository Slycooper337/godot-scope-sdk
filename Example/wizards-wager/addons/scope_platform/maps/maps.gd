class_name ScopeMaps
extends RefCounted

var _api: ScopeAPI


func _init(api: ScopeAPI) -> void:
	_api = api


func get_definition(world_id: String, map_id: String) -> ScopeResponse:
	return await _api.request_get(_definition_endpoint(world_id, map_id))


func validate_definition(world_id: String, map_id: String, definition: Dictionary) -> ScopeResponse:
	return await _api.request_post(_validate_endpoint(world_id, map_id), {"definition": definition})


func publish_definition(world_id: String, map_id: String, definition: Dictionary, expected_version: int = 0) -> ScopeResponse:
	return await _api.request_put(_definition_endpoint(world_id, map_id), {
		"expected_version": expected_version,
		"definition": definition
	})


func list_versions(world_id: String, map_id: String) -> ScopeResponse:
	return await _api.request_get(_versions_endpoint(world_id, map_id))


func _definition_endpoint(world_id: String, map_id: String) -> String:
	return "/worlds/%s/maps/%s/definition" % [world_id.uri_encode(), map_id.uri_encode()]


func _validate_endpoint(world_id: String, map_id: String) -> String:
	return "/worlds/%s/maps/%s/validate" % [world_id.uri_encode(), map_id.uri_encode()]


func _versions_endpoint(world_id: String, map_id: String) -> String:
	return "/worlds/%s/maps/%s/versions" % [world_id.uri_encode(), map_id.uri_encode()]
