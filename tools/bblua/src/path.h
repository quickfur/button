/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Path manipulation module.
 */
#pragma once

/**
 * Unix paths use forward slashes ('/') as directory separators. Absolute paths
 * begin with a directory separator.
 */
#define PATH_STYLE_UNIX 0

/**
 * Windows (not DOS!) paths use backslashes ('\') or forward slashes ('/') as
 * directory separators. Drive letters can be prepended to either absolute or
 * relative paths. Networked (UNC) paths begin with a double backslash ("\\").
 */
#define PATH_STYLE_WIN 1

#ifndef PATH_STYLE
#   ifdef _WIN32
#      define PATH_STYLE PATH_STYLE_WIN
#   else
#      define PATH_STYLE PATH_STYLE_UNIX
#   endif
#endif

/**
 * Default path separator to use when constructing paths. If you want Windows to
 * have a forward slash ('\') as the default path separator, change that here.
 */
#ifndef PATH_SEP
#	if PATH_STYLE == PATH_STYLE_WIN
#		define PATH_SEP '\\'
#	else
#		define PATH_SEP '/'
#	endif
#endif

struct lua_State;

/**
 * Returns true if the path is absolute, false otherwise.
 */
int path_isabs(lua_State* L);

/**
 * Returns a path with all path elements joined together.
 */
int path_join(lua_State* L);

/**
 * Returns the head and tail of the path where the tail is the last path
 * element and the head is everything leading up to it.
 */
int path_split(lua_State* L);

/**
 * Returns the last path element. This is the same as the tail of path_split().
 */
int path_basename(lua_State* L);

/**
 * Returns the everything except for the basename of the path. This is the same
 * as the head of path_split().
 */
int path_dirname(lua_State* L);

/**
 * Splits the path into a root and extension such that concatenating the root
 * and extension returns the original path.
 */
int path_splitext(lua_State* L);

/**
 * Returns the extension of the path. This is the same as splitting by extension
 * and retrieving just the extension part.
 */
int path_getext(lua_State* L);

/**
 * Normalizes the path such that redundant path separators and up=level
 * references are collapsed.
 */
int path_norm(lua_State* L);

/**
 * Pushes the path library onto the stack so that it can be registered.
 */
int luaopen_path(lua_State* L);