--[[
MIT License
Copyright (c) 2024-2025 sigma-axis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

https://mit-license.org/
]]

--
-- VERSION: v1.11-beta1
--

--------------------------------

local fmt_name_scene_cache, fmt_name_stack_cache, fmt_name_scene_cache_str =
	"cache:ILS_S/S%02d/%s", "cache:ILS_S/F%02d/%02d", "cache:ILS_S/A@%s/%s";
local name_cache_temp = "cache:ILS_S/T";
local interval_collection = 300;

local warning_style_lead, warning_style_body =
	"\27[91m\27[4m", -- bright red, underline.
	"\27[31m\27[24m"; -- red, no underline.
--[[
-- 文字色を変える場合は，以下のように書き換えて "[38;2;<R>;<G>;<B>m" の部分を指定．
local warning_style_lead, warning_style_body =
	"\27[38;2;255;255;255m\27[4m", -- RGB(255, 255, 255) の白色．
	"\27[38;2;255;128;0m\27[24m"; -- RGB(255, 128, 0) のオレンジ．
-- ref: https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
]]
local function emit_warning(lead, body)
	debug_print(warning_style_lead..lead..warning_style_body..body);
end

local obj, math, tonumber, tostring, table, pairs, os_clock = obj, math, tonumber, tostring, table, pairs, os.clock;
local error_mod do
	function error_mod(message)
		local this_file = debug.getinfo(1).source:match("^.*[/\\](.-)$");
		emit_warning(this_file, ": "..message);
		message = this_file..": "..message;
		local function err_mes()
			obj.setfont("MS UI Gothic", 42, 3);
			obj.load("text", message);
		end
		return setmetatable({}, { __index = function(...) return err_mes end });
	end
end

-- make sure patch.aul is installed (for the use of obj.getvalue("cx")).
if not _PATCH then
	return error_mod [=[このスクリプトの実行には patch.aul が必要です!]=];
end
if not obj.getvalue("cx") then
	return error_mod [=[このスクリプトの実行には patch.aul の設定 patch.aul.json で "switch" -> "lua.getvalue" が true である必要があります!]=];
end

-- make sure the use of LuaJIT.
if not jit then
	return error_mod [=[このスクリプトの実行には LuaJIT が必要です!]=];
end
local bit_band, bit_bor = bit.band, bit.bor;

-- reading (and sometimes writing) internal data of exedit using FFI and pointer manipulation.
local ffi = require "ffi";
ffi.cdef[[
	void* GetModuleHandleA(char const* moduleName);
]]
local get_render_cycle, get_is_playing,
	get_scene_flags, set_scene_flags, get_obj_flags,
	get_frame_buffer, get_obj_edit, get_buffer_stride,
	get_current_frame, get_current_scene, get_scene_name, exfunc_bufcpy, exfunc_fill,
	max_h_inline_scene, determine_bounding_box do

	local h_aviutl = ffi.cast("uintptr_t", ffi.C.GetModuleHandleA(nil));
	-- check for the version of aviutl.exe. (may be unnecessary; as patch.aul exist.)
	if h_aviutl == 0 or
		ffi.cast("int32_t*", h_aviutl + 0x068108)[0] ~= 11003 or
		ffi.string(ffi.cast("char*", h_aviutl + 0x07425c), 5) ~= "1.10\0" then
		return error_mod [=[AviUtl のバージョンが 1.10 ではありません!]=];
	end

	local h_exedit = ffi.cast("uintptr_t", ffi.C.GetModuleHandleA("exedit.auf"));
	-- check for the version of exedit.auf. (may be unnecessary; as patch.aul exist and Lua is running.)
	if h_exedit == 0 then return error_mod [=[拡張編集が見つかりません!]=];
	else
		local info_v092 = [=[拡張編集(exedit) version 0.92 by ＫＥＮくん]=]..'\0';
		local info_curr = ffi.string(ffi.cast("char*", h_exedit + 0x0a4400), #info_v092);
		if info_curr ~= info_v092 then
			return error_mod [=[拡張編集のバージョンが 0.92 ではありません!]=];
		end
	end

	-- locate FilterProcInfo of exedit and other pointers.
	local render_cycle, max_scene_w, max_scene_h = h_aviutl + 0x0a8c34, h_aviutl + 0x086444, h_aviutl + 0x08626c;
	local efpip, scene_settings, is_playing, exfunc = h_exedit + 0x1b2b20, h_exedit + 0x177a50, h_exedit + 0x1a52e8, h_exedit + 0x0a41e0;
	local efpip2 = ffi.cast("uint32_t**", efpip);
	local function get_efpip_flag_ptr()
		return efpip2[0] + 0x00/4; -- reading &efpip->flag.
	end
	function get_scene_flags()
		local flags = get_efpip_flag_ptr()[0];
		-- checking `efpip->flag` has certain bits:
		-- bit 8: `frame_alpha`; whether the frame buffer is of YCA format.
		-- bit 12: `nesting`; whether the scene is being referred by an object.
		return bit_band(flags, 2^8) ~= 0, bit_band(flags, 2^12) ~= 0;
	end
	function set_scene_flags(has_alpha, is_nesting)
		local ptr = get_efpip_flag_ptr();
		ptr[0] = bit_bor(bit_band(ptr[0], -1 - 2^8 - 2^12),
			has_alpha and 2^8 or 0, -- `frame_alpha` flag.
			is_nesting and 2^12 or 0); -- `nesting` flag.
	end
	---現在シーンの冒頭からのフレーム数を取得する．
	---@return integer # フレーム数，冒頭は `0`.
	function get_current_frame()
		return efpip2[0][0xa8/4]; -- reading efpip->frame_num.
	end
	function get_buffer_stride()
		return efpip2[0][0xec/4]; -- reading efpip->obj_line.
	end
	function get_obj_flags()
		local flags = efpip2[0][0xf8/4]; -- reading efpip->object_flag.
		-- checking it has certain bits:
		-- bit 0: whether "off-screen draw" is done.
		-- bit 17: whether `obj.effect()` is being called from former scripts.
		return bit_band(flags, 1) ~= 0, bit_band(flags, 2^17) ~= 0;
	end

	local efpip3 = ffi.cast("int16_t***", efpip);
	function get_frame_buffer()
		return efpip3[0][0x04/4]; -- reading efpip->frame_edit.
	end
	function get_obj_edit()
		return efpip3[0][0xac/4]; -- reading efpip->obj_edit.
	end

	local function get_current_object()
		return efpip3[0][0x13c/4]; -- reading efpip->objectp.
	end
	---現在オブジェクトのシーン番号を取得する．
	---@return integer scene_idx Root は `0`, Scene 1 は `1`, ...
	function get_current_scene()
		local objectp = get_current_object();
		if objectp == nil then return 0 end
		return objectp[0x5c4/2]; -- reading objectp->scene_set (lower 16 bits).
	end

	local is_playing1 = ffi.cast("int32_t*", is_playing);
	---現在プレビュー再生中であるかどうかを取得する．保存中 (`obj.getinfo("saving")` が `true`) の場合の戻り値は `false`.
	---@return boolean # `true` だとプレビュー再生中，`false` だと編集作業中．
	function get_is_playing() return is_playing1[0] ~= 0 end

	local scene_settings2 = ffi.cast("char**", scene_settings);
	function get_scene_name(scene_idx)
		local ptr = scene_settings2[(scene_idx * 0x60 + 0x04)/4]; -- reading scene_settings[scene_idx].name.
		if ptr == nil then return nil end
		local str = ffi.string(ptr);
		if str == "" then return nil end
		return str;
	end

	local render_cycle1 = ffi.cast("int32_t*", render_cycle);
	function get_render_cycle() return render_cycle1[0] end

	-- function pointers for buffer operations.
	-- ref: https://github.com/ePi5131/aviutl_exedit_sdk/blob/master/exedit/Exfunc.hpp
	local exfunc2 = ffi.cast("void**", exfunc);

	-- BOOL (*bufcpy)(void* dst, int32_t dst_w, int32_t dst_h, void* src, int32_t src_w, int32_t src_h, int32_t w, int32_t h, int32_t alpha, int32_t flag);
	exfunc_bufcpy = ffi.cast("int32_t(__cdecl*)(void*, int32_t, int32_t, void*, int32_t, int32_t, int32_t, int32_t, int32_t, int32_t)",
		exfunc2[0x44/4]);

	-- uint32_t (*fill)(void* ycp, int32_t wo, int32_t ho, int32_t w, int32_t h, int16_t y, int16_t cb, int16_t cr, int16_t a, int32_t flag);
	exfunc_fill = ffi.cast("uint32_t(__cdecl*)(void*, int32_t, int32_t, int32_t, int32_t, int16_t, int16_t, int16_t, int16_t, int32_t)",
		exfunc2[0x48/4]);

	-- determine maximum height for an inline scene.
	local max_scene_w1, max_scene_h1, max_image_w1, _
		= ffi.cast("int32_t*", max_scene_w)[0], ffi.cast("int32_t*", max_scene_h)[0], obj.getinfo("image_max");
	max_h_inline_scene = math.floor(
		(6 * (max_scene_w1 + 8) * max_scene_h1) / (8 * (max_image_w1 + 8)));

	-- take advantage of CropBlank_S.eef if exists.
	if ffi.C.GetModuleHandleA("CropBlank_S.eef") ~= nil then
		if not package.loaded.CropBlank_S then
			package.preload.CropBlank_S = package.loadlib("CropBlank_S.eef", "luaopen_CropBlank_S");
		end
		local CropBlank_S = require "CropBlank_S";
		determine_bounding_box = CropBlank_S.bounding_box;
	end
end

---現在オブジェクトが「オフスクリーン描画」が実行された後の状態で，座標関連の取り扱いが特殊な状況であるかどうかを取得する．
---@return boolean # `true` で「オフスクリーン描画」済み，`false` で「オフスクリーン描画」がされていない．
local function offscreen_drawn()
	local ret, _ = get_obj_flags();
	return ret;
end
local function clear_framebuffer(w, h, has_alpha)
	exfunc_fill(get_frame_buffer(), 0, 0, w, h, 0, 0, 0, 0, has_alpha and 2 or 0);
end
-- local function copy_buffer(dst, src, w, h, dst_has_alpha, src_has_alpha)
-- 	exfunc_bufcpy(dst, 0, 0, src, 0, 0, w, h, 0,
-- 		bit_bor(0x13000000, dst_has_alpha and 2 or 0, src_has_alpha and 1 or 0));
-- end
local function copy_obj_to_frame(w, h, has_alpha)
	exfunc_bufcpy(get_frame_buffer(), 0, 0, get_obj_edit(), 0, 0, w, h, 0,
		bit_bor(0x13000001, has_alpha and 2 or 0));
end

-- ref: https://github.com/Mr-Ojii/AviUtl-AutoClipping_M-Script
if not determine_bounding_box then
	local function find_t(l, t, r, b, threshold, buf, stride)
		for y = t, b do for x = l, r do
			if buf[4 * x + y * stride + 3] > threshold then return x, y end
		end end
		return nil, b + 1;
	end
	local function find_b(l, t, r, b, threshold, buf, stride)
		for y = b, t + 1, -1 do for x = r, l, -1 do
			if buf[4 * x + y * stride + 3] > threshold then return x, y end
		end end
		return nil, t;
	end
	local function find_l(l, t, r, b, threshold, buf, stride)
		for y = b, t + 1, -1 do for x = l, r - 1 do
			if buf[4 * x + y * stride + 3] > threshold then r = x; break end
		end end
		return r;
	end
	local function find_r(l, t, r, b, threshold, buf, stride)
		for y = t, b - 1 do for x = r, l + 1, -1 do
			if buf[4 * x + y * stride + 3] > threshold then l = x; break end
		end end
		return l;
	end
	function determine_bounding_box(l, t, r, b, threshold)
		local buf, stride = get_obj_edit(), 4 * get_buffer_stride();
		threshold = math.min(math.max(math.floor(threshold), 0), 4095);
		r, b = r - 1, b - 1;
		local x1, x2;

		-- determine the top.
		x1, t = find_t(l, t, r, b, threshold, buf, stride);
		if not x1 then return nil end -- entirely transparent.

		-- then bottom.
		x2, b = find_b(l, t, r, b, threshold, buf, stride);

		-- next left and right.
		if x2 then x1, x2 = math.min(x1, x2), math.max(x1, x2) else x2 = x1 end
		l = find_l(l, t, x1, b, threshold, buf, stride);
		r = find_r(x2, t, r, b, threshold, buf, stride);

		-- return the bounding box (L, T, R, B).
		return l, t, r + 1, b + 1;
	end
end
local function resize_foursides(ext_l, ext_t, ext_r, ext_b)
	if ext_l < 0 or ext_t < 0 or ext_r < 0 or ext_b < 0 then
		obj.effect("クリッピング",
			"左", math.max(-ext_l, 0), "上", math.max(-ext_t, 0),
			"右", math.max(-ext_r, 0), "下", math.max(-ext_b, 0));
	end
	if ext_l > 0 or ext_t > 0 or ext_r > 0 or ext_b > 0 then
		obj.effect("領域拡張",
			"左", math.max(ext_l, 0), "上", math.max(ext_t, 0),
			"右", math.max(ext_r, 0), "下", math.max(ext_b, 0));
	end
	-- returns the moves of `obj.cx` and `obj.cy`.
	return (ext_l - ext_r) / 2, (ext_t - ext_b) / 2;
end
local function crop_foursides(ext_l, ext_t, ext_r, ext_b, width, height)
	local l, t, r, b = determine_bounding_box(0, 0, width, height, 0);
	if not l then
		-- all pixels are transparent.
		obj.effect("クリッピング", "左", width, "上", height, "中心の位置を変更", 1);
		return 0, 0;
	end
	r, b = width - r, height - b;
	return resize_foursides(ext_l - l, ext_t - t, ext_r - r, ext_b - b);
end
---現在オブジェクトの指定矩形内で，アルファ値がしきい値を超えるピクセル全てを囲む最小の矩形を特定する．
---引数の `left` が `nil` の場合はオブジェクト全体が検索の対象範囲となる．
---全てのピクセルがしきい値以下だった場合は `nil` を返す．
---座標の範囲は，左/上は inclusive, 右/下は exclusive, ピクセル単位で左上が原点．
---@param left integer? ピクセル検索範囲の左端の X 座標．
---@param top integer? ピクセル検索範囲の上端の Y 座標．
---@param right integer? ピクセル検索範囲の右端の X 座標．
---@param bottom integer? ピクセル検索範囲の下端の Y 座標．
---@param threshold integer? 検索対象のアルファ値のしきい値，0 以上 4096 未満の整数．既定値は 0.
---@return integer? left 存在領域の左端の X 座標．
---@return integer top 存在領域の上端の Y 座標．
---@return integer right 存在領域の右端の X 座標．
---@return integer bottom 存在領域の下端の Y 座標．
local function bounding_box(left, top, right, bottom, threshold)
	if not left then left, top, right, bottom = 0, 0, obj.getpixel() end
---@diagnostic disable-next-line: return-type-mismatch
	return determine_bounding_box(left, top, right, bottom, threshold);
end

local function aspect2zoom(aspect)
	if aspect > 0 then return math.max(1 - aspect, 0), 1;
	else return 1, math.max(1 + aspect, 0) end
end
local function zoom2aspect(zoom_x, zoom_y)
	if zoom_x < zoom_y then return zoom_y, 1 - zoom_x / zoom_y;
	elseif zoom_x > 0 then return zoom_x, -1 + zoom_y / zoom_x;
	else return 0, 0 end
end
---2つの縦横比を組み合わせ，拡大率と縦横比の組に計算する補助関数．縦横比は `-1.0` から `1.0` の範囲．
---@param zoom number 拡大率．
---@param aspect1 number 組み合わられる縦横比 1.
---@param aspect2 number 組み合わられる縦横比 2.
---@return number zoom 組み合わせた結果の拡大率．
---@return number aspect 組み合わせた結果の縦横比．
local function combine_aspect(zoom, aspect1, aspect2)
	local zx1, zy1 = aspect2zoom(aspect1);
	local zx2, zy2 = aspect2zoom(aspect2);
	local Z, A = zoom2aspect(zx1 * zx2, zy1 * zy2);
	return zoom * Z, A;
end

local read_scene, write_scene, clear_scenes do
	local function coerce_scene_idx(scene_idx)
		local idx = tonumber(scene_idx);
		if idx and idx >= 0 and idx < 50 then return math.floor(idx), true;
		else return tostring(scene_idx):gsub("[@/]", "@%1"), false end
	end
	local function fmt_cache_name(name, scene_idx)
		local idx, is_num = coerce_scene_idx(scene_idx);
		if is_num then return fmt_name_scene_cache:format(idx, name);
		else return fmt_name_scene_cache_str:format(idx, name) end
	end
	local function init_metrics(self)
		self.w = 0; self.h = 0;
		self.ox = 0.0; self.oy = 0.0; self.oz = 0.0;
		self.rx = 0.0; self.ry = 0.0; self.rz = 0.0;
		self.cx = 0.0; self.cy = 0.0; self.cz = 0.0;
		self.zoom = 1.0; self.aspect = 0.0; self.alpha = 1.0;
	end
	local function new(name, scene_idx)
		return {
			frame = -1,
			cycle = -1,
			ever_used = true,

			name = fmt_cache_name(name, scene_idx),
			---@class inline_scene_s.metrics_tbl キャッシュデータのサイズや回転に関する情報を格納．
			---@field w integer キャッシュデータの横幅，ピクセル単位．
			---@field h integer キャッシュデータの高さ，ピクセル単位．
			---@field ox number 位置情報の X 座標，`obj.x + obj.ox` の記録を想定．
			---@field oy number 位置情報の Y 座標，`obj.y + obj.oy` の記録を想定．
			---@field oz number 位置情報の Z 座標，`obj.z + obj.oz` の記録を想定．
			---@field rx number X 軸回転角度，度数法．`obj.rx` の記録を想定．
			---@field ry number Y 軸回転角度，度数法．`obj.ry` の記録を想定．
			---@field rz number Z 軸回転角度，度数法．`obj.rz` の記録を想定．
			---@field cx number 回転中心の X 座標，`obj.cx` の記録を想定．
			---@field cy number 回転中心の Y 座標，`obj.cy` の記録を想定．
			---@field cz number 回転中心の Z 座標，`obj.cz` の記録を想定．
			---@field zoom number 拡大率，等倍は `1.0`. `obj.zoom * obj.getvalue("zoom") / 100` の記録を想定．
			---@field aspect number 縦横比，`-1.0` から `+1.0`. 正で縦長，負で横長．`obj.aspect` と `obj.getvalue("aspect")` を加味した値の記録を想定．
			---@field alpha number 不透明度，完全不透明は `1.0`. `obj.alpha * obj.getvalue("alpha")` の記録を想定．
			---@field init function テーブル内の情報を初期値に戻す．
			metrics = {
				w = 0, h = 0,
				ox = 0.0, oy = 0.0, oz = 0.0,
				rx = 0.0, ry = 0.0, rz = 0.0,
				cx = 0.0, cy = 0.0, cz = 0.0,
				zoom = 1.0, aspect = 0.0, alpha = 1.0,
				init = init_metrics,
			},
		};
	end
	local data_table = {};
	local time_collection = os_clock();
	local function collect()
		-- do not delete data while saving or previewing.
		if obj.getinfo("saving") or get_is_playing() then return end

		local time_current = os_clock();
		if time_current < time_collection + interval_collection then return end
		time_collection = time_current;

		for _, subtable in pairs(data_table) do
			for name, data in pairs(subtable) do
				if data.ever_used then data.ever_used = false;
				else subtable[name] = nil end
			end
		end
	end

	local function query_scene(name, curr_cycle, curr_frame, scene_idx)
		local idx = coerce_scene_idx(scene_idx);
		local subtable = data_table[idx];
		if not subtable then
			subtable = {};
			data_table[idx] = subtable;
		end
		local data, status, age = subtable[name], nil, nil;
		if data then
			-- data is found, check if it's contiguous with the last render.
			if data.frame >= 0 then
				if curr_frame < data.frame then status = "yet";
				elseif curr_frame > data.frame then status = "old";
				elseif curr_cycle == data.cycle then status = "new";
				else status = "yet" end
				age = curr_frame - data.frame;
			end
		else
			-- create a new metadata for the "inline scene".
			data = new(name, idx);
			subtable[name] = data;
		end

		data.ever_used = true;
		collect();

		return data, status, age;
	end
	---"Inline scene" 管理下のキャッシュデータを読み出し目的で取得．
	---@param name string "Inline scene" の名前．
	---@param scene_idx integer|string|nil 取得対象のシーン番号，または独自の名前．`nil` の場合は現在オブジェクトのシーン番号．
	---@return string cache_name `obj.copybuffer()` で使える "cache:" から始まるキャッシュ名．
	---@return inline_scene_s.metrics_tbl metrics "Inline scene" のサイズや位置，回転角度の情報を格納したテーブル．`read_cache()` で取得した場合は中身を上書きしないこと．
	---@return "yet"|"new"|"old"|nil status "Inline scene" が最後に書き込まれた段階を表す．<br>`"yet"`: 現在よりも後の段階（同一フレームの再描画や巻き戻しなどが起こった），<br>`"new"`: 現在よりも前の段階で，同一フレーム，<br>`"old"`: 現在よりも前のフレーム,<br>`nil`: そもそも書き込みが起こっていない．
	---@return integer? age "Inline scene" が最後に書き込まれてからの経過フレーム数．`status` が `nil` の場合は `nil`.
	function read_scene(name, scene_idx)
		local scene, status, age = query_scene(name, get_render_cycle(), get_current_frame(), scene_idx or get_current_scene());
		local readable = status ~= nil and scene.metrics.w > 0 and scene.metrics.h > 0;
		return scene.name, scene.metrics, readable and status or nil, readable and age or nil;
	end
	---"Inline scene" 管理下のキャッシュデータを書き込み目的で取得．
	---@param name string "Inline scene" の名前．
	---@param scene_idx integer|string|nil 取得対象のシーン番号，または独自の名前．`nil` の場合は現在オブジェクトのシーン番号．
	---@return string cache_name `obj.copybuffer()` で使える "cache:" から始まるキャッシュ名．
	---@return inline_scene_s.metrics_tbl metrics "Inline scene" のサイズや位置，回転角度の情報を格納したテーブル．更新が必要なら中身を書き換えること．
	---@return "yet"|"new"|"old"|nil status "Inline scene" が最後に書き込まれた段階を表す．<br>`"yet"`: 現在よりも後の段階（同一フレームの再描画や巻き戻しなどが起こった），<br>`"new"`: 現在よりも前の段階で，同一フレーム，<br>`"old"`: 現在よりも前のフレーム,<br>`nil`: そもそも書き込みが起こっていない．
	---@return integer? age "Inline scene" が最後に書き込まれてからの経過フレーム数．`status` が `nil` の場合は `nil`.
	function write_scene(name, scene_idx)
		local curr_cycle, curr_frame = get_render_cycle(), get_current_frame();
		local scene, status, age = query_scene(name, curr_cycle, curr_frame, scene_idx or get_current_scene());
		local readable = status ~= nil and scene.metrics.w > 0 and scene.metrics.h > 0;

		scene.cycle = curr_cycle;
		scene.frame = curr_frame;

		if not readable then scene.metrics:init() end
		return scene.name, scene.metrics, readable and status or nil, readable and age or nil;
	end
	---"Inline scene" のデータを破棄する．
	---@param scene_idx integer|string|nil 破棄対象のシーン番号，または独自の名前．`nil` の場合は現在オブジェクトのシーン番号．
	---@param all boolean? 全てのシーン番号と独自名に属するデータを破棄する．既定値は `false`.
	function clear_scenes(scene_idx, all)
		if all then data_table = {};
		else data_table[coerce_scene_idx(scene_idx or get_current_scene())] = nil end
	end
end

local function scene_disp(scene_idx)
	local ret = scene_idx == 0 and "Root" or ("Scene "..scene_idx);
	local name = get_scene_name(scene_idx);
	if name then ret = name.." ("..ret..")" end
	if name or scene_idx == 0 then ret = "Scene: "..ret end
	return ret;
end
local query_stack do
	local function format_bk_name(scene_idx, height)
		return fmt_name_stack_cache:format(scene_idx, height);
	end
	local function warn_unclosed(stack)
		local L = {};
		for i = #stack.stack, 1, -1 do table.insert(L, stack.stack[i].layer) end
		local leftovers = table.concat(L, ", ");
		if #L > 1 then leftovers = "{ "..leftovers.." }" end
		local scr_name = obj.getoption("script_name");
		if scr_name == "" then scr_name = "スクリプト制御" end
		emit_warning(("[Inline Scene] %s, Frame: %d, Layer%s: %s\n\t")
			:format(scene_disp(stack.scene), stack.frame, #L == 1 and "" or "s", leftovers),
			([=[Inline Scene が正しく閉じられなかった可能性があります! (検出は Frame: %d, Layer: %d の "%s")]=])
			:format(get_current_frame(), obj.layer, scr_name));
	end
	local function push_stack(self, has_alpha, is_nesting)
		local ret = {
			cache_name = format_bk_name(self.scene, #self.stack),
			has_alpha = has_alpha,
			is_nesting = is_nesting,
			layer = obj.layer,
		};
		table.insert(self.stack, ret);
		return ret;
	end
	local function pop_stack(self)
		if #self.stack == 0 then return nil end
		return table.remove(self.stack);
	end
	local function clear_stack(self, do_warn)
		if #self.stack == 0 then return nil end
		if do_warn then warn_unclosed(self) end
		local bottom = self.stack[1];
		self.stack = {};
		return bottom;
	end
	local function new(scene_idx)
		return {
			scene = scene_idx,
			frame = get_current_frame(),
			cycle = get_render_cycle(),
			stack = {},

			push = push_stack,
			pop = pop_stack,
			clear = clear_stack,
		};
	end
	local data_table = {};
	function query_stack(scene_idx)
		local stack = data_table[scene_idx];
		if not stack then
			stack = new(scene_idx);
			data_table[scene_idx] = stack;
		else
			local curr_frame, curr_cycle = get_current_frame(), get_render_cycle();
			if #stack.stack > 0 and stack.cycle ~= curr_cycle then
				-- here in this context, `#stack.stack > 0` must satisfy.
				warn_unclosed(stack);
				stack.stack = {};
			end
			stack.frame = curr_frame;
			stack.cycle = curr_cycle;
		end
		return stack;
	end
end

local function warn_unopened(scene_idx, curr_frame, layer)
	local scr_name = obj.getoption("script_name");
	if scr_name == "" then
		scr_name = [=[End() / Next()" の呼び出しを含む "スクリプト制御]=];
	end
	emit_warning(("[Inline Scene] %s, Frame: %d, Layer: %d\n\t")
		:format(scene_disp(scene_idx), curr_frame, layer),
		([=[Inline Scene が開いていない状態で "%s" が適用されました! Inline Scene オブジェクト / フィルタ効果の配置が正しくない可能性があります!]=]):format(scr_name));
end

local function warn_on_obj_effect(scene_idx, curr_frame, layer)
	local scr_name = obj.getoption("script_name");
	if scr_name == "" then
		scr_name = [=[Begin() / End() / Next()" の呼び出しを含む "スクリプト制御]=];
	end
	emit_warning(("[Inline Scene] %s, Frame: %d, Layer: %d\n\t")
		:format(scene_disp(scene_idx), curr_frame, layer),
		([=["%s" は obj.effect() の引数なし呼び出しを含むスクリプトの後続フィルタとして配置できません! また，モーションブラー等の一部フィルタ効果は適用できません!]=])
		:format(scr_name));
end

local function warn_multi_obj(scene_idx, curr_frame, layer)
	local scr_name = obj.getoption("script_name");
	if scr_name == "" then
		scr_name = [=[Begin() / End() / Next()" の呼び出しを含む "スクリプト制御]=];
	end
	emit_warning(("[Inline Scene] %s, Frame: %d, Layer: %d\n\t")
		:format(scene_disp(scene_idx), curr_frame, layer),
		([=["%s" は個別オブジェクトには適用しないでください!]=]):format(scr_name));
end

local function warn_camera(scene_idx, curr_frame, layer)
	local scr_name = obj.getoption("script_name");
	if scr_name == "" then
		scr_name = [=[Begin() / End() / Next()" の呼び出しを含む "スクリプト制御]=];
	end
	emit_warning(("[Inline Scene] %s, Frame: %d, Layer: %d\n\t")
		:format(scene_disp(scene_idx), curr_frame, layer),
		([=["%s" はカメラ制御下には配置しないでください!]=]):format(scr_name));
end

local function warn_image_size(scene_idx, curr_frame, layer)
	local scr_name = obj.getoption("script_name");
	if scr_name == "" then
		scr_name = [=[Begin()" の呼び出しを含む "スクリプト制御]=];
	end
	emit_warning(("[Inline Scene] %s, Frame: %d, Layer: %d\n\t")
		:format(scene_disp(scene_idx), curr_frame, layer),
		([=[AviUtl の環境設定の最大画像サイズが小さいため "アルファチャンネルあり" の "%s" が使えません! 高さがシーンの 4/3 倍以上必要です．詳しくは README を参照．]=]):format(scr_name));
end

---"Inline scene" の状態を開始する．
---フレームバッファをキャッシュに退避し消去，一部フラグを書き換える．次の `End()` の呼び出しで復元される．
---tempbuffer は他データで上書きされるので注意．
---@param has_alpha boolean 開始した "Inline scene" が「アルファチャンネルあり」に相当する挙動かどうかを指定する．
local function begin_inline_scene(has_alpha)
	-- check warning conditions.
	if obj.getoption("multi_object") then
		warn_multi_obj(get_current_scene(), get_current_frame(), obj.layer);
		return;
	end
	if obj.getoption("camera_mode") ~= 0 then
		warn_camera(get_current_scene(), get_current_frame(), obj.layer);
		return;
	end
	local _, on_obj_effect = get_obj_flags();
	if on_obj_effect then
		warn_on_obj_effect(get_current_scene(), get_current_frame(), obj.layer);
		return;
	end

	local had_alpha, was_nesting = get_scene_flags();
	if not had_alpha and has_alpha and obj.screen_h > max_h_inline_scene then
		warn_image_size(get_current_scene(), get_current_frame(), obj.layer);
		return;
	end
	local stack = query_stack(get_current_scene());

	-- core process.
	local info = stack:push(had_alpha, was_nesting);

	obj.copybuffer("tmp", "frm");
	obj.copybuffer(info.cache_name, "tmp");

	if has_alpha ~= had_alpha then set_scene_flags(has_alpha, false) end
	clear_framebuffer(obj.screen_w, obj.screen_h, has_alpha);
end

local function crop_and_save(crop, ext_l, ext_t, ext_r, ext_b, name, scene_idx)
	local dcx, dcy;
	-- crop the four sides if necessary.
	if crop then
		dcx, dcy = crop_foursides(ext_l, ext_t, ext_r, ext_b, obj.screen_w, obj.screen_h);
	else dcx, dcy = resize_foursides(ext_l, ext_t, ext_r, ext_b) end

	-- store to cache with the specified name.
	if name then
		local cache_name, metrics, _, _ = write_scene(tostring(name), scene_idx);

		obj.copybuffer(cache_name, "obj");
		metrics:init();
		metrics.w, metrics.h = obj.getpixel();
		metrics.cx = dcx; metrics.cy = dcy;
	end

	return dcx, dcy;
end

---"Inline scene" の状態を終了する．
---現在のフレームバッファをオブジェクトやキャッシュとして再利用可能にして，
---`Begin()` で退避したフレームバッファとフラグを復元する．
---現在オブジェクトの内容はフレームバッファの内容で上書きされる．余白調整量に応じて `obj.cx`, `obj.cy` も変化する．
---tempbuffer は他データで上書きされるので注意．
---@param crop boolean? 上下左右の完全透明ピクセルを取り除く．既定値は `false`.
---@param ext_l integer 描画・保存前に追加する左余白幅．負だとクリッピング．
---@param ext_t integer 描画・保存前に追加する上余白幅．負だとクリッピング．
---@param ext_r integer 描画・保存前に追加する右余白幅．負だとクリッピング．
---@param ext_b integer 描画・保存前に追加する下余白幅．負だとクリッピング．
---@param name string? "Inline scene" として保存する場合の名前．この名前は `recall()` や `save()`, `read_cache()`, `write_cache()` などで利用できる．`nil` の場合は保存しない．
local function end_inline_scene(crop, ext_l, ext_t, ext_r, ext_b, name)
	-- check warning conditions.
	if obj.getoption("multi_object") then
		warn_multi_obj(get_current_scene(), get_current_frame(), obj.layer);
		return;
	end
	if obj.getoption("camera_mode") ~= 0 then
		warn_camera(get_current_scene(), get_current_frame(), obj.layer);
		return;
	end
	local _, on_obj_effect = get_obj_flags();
	if on_obj_effect then
		warn_on_obj_effect(get_current_scene(), get_current_frame(), obj.layer);
		return;
	end

	local has_alpha, _ = get_scene_flags();
	local stack = query_stack(get_current_scene());
	local info = stack:pop();

	-- check the warning condition for the former inline scene.
	if not info then
		warn_unopened(stack.scene, stack.frame, obj.layer);
		return;
	end

	-- transfer the current frame to obj, and cached frame to the frame buffer.
	obj.copybuffer("tmp", "frm");
	set_scene_flags(info.has_alpha, info.is_nesting);
	obj.copybuffer("obj", info.cache_name);
	copy_obj_to_frame(obj.screen_w, obj.screen_h, info.has_alpha);
	obj.copybuffer("obj", "tmp");

	-- crop and save to the cache, if necessary.
	crop_and_save(has_alpha and crop, ext_l, ext_t, ext_r, ext_b, name, stack.scene);
end

---`End()` を呼び出し，その後に `Begin()` を呼び出すのに相当する処理をする．
---ただしコピー回数が少なく，現在オブジェクトの内容や `obj.cx`, `obj.cy` が変化しない点が異なる．
---@param crop boolean? 上下左右の完全透明ピクセルを取り除く．既定値は `false`.
---@param ext_l integer 描画・保存前に追加する左余白幅．負だとクリッピング．
---@param ext_t integer 描画・保存前に追加する上余白幅．負だとクリッピング．
---@param ext_r integer 描画・保存前に追加する右余白幅．負だとクリッピング．
---@param ext_b integer 描画・保存前に追加する下余白幅．負だとクリッピング．
---@param name string "Inline scene" として保存する場合の名前．この名前は `recall()` や `save()`, `read_cache()`, `write_cache()` などで利用できる．
---@param has_alpha boolean 次の "Inline scene" が「アルファチャンネルあり」に相当する挙動かどうかを指定する．
local function next_inline_scene(crop, ext_l, ext_t, ext_r, ext_b, name, has_alpha)
	-- check warning conditions.
	if obj.getoption("multi_object") then
		warn_multi_obj(get_current_scene(), get_current_frame(), obj.layer);
		return;
	end
	if obj.getoption("camera_mode") ~= 0 then
		warn_camera(get_current_scene(), get_current_frame(), obj.layer);
		return;
	end
	local _, on_obj_effect = get_obj_flags();
	if on_obj_effect then
		warn_on_obj_effect(get_current_scene(), get_current_frame(), obj.layer);
		return;
	end

	local had_alpha, _ = get_scene_flags();
	if not had_alpha and has_alpha and obj.screen_h > max_h_inline_scene then
		warn_image_size(get_current_scene(), get_current_frame(), obj.layer);
		return;
	end
	local stack = query_stack(get_current_scene());

	-- check the warning condition for the former inline scene.
	if #stack.stack == 0 then
		warn_unopened(stack.scene, stack.frame, obj.layer);
		return;
	end

	-- transfer the current frame to obj.
	obj.copybuffer(name_cache_temp, "obj");
	obj.copybuffer("obj", "frm");

	-- crop and save to the cache.
	local dcx, dcy = crop_and_save(had_alpha and crop, ext_l, ext_t, ext_r, ext_b, name, stack.scene);
	obj.cx, obj.cy = obj.cx - dcx, obj.cy - dcy;

	-- restore the current object.
	obj.copybuffer("obj", name_cache_temp);

	-- prepare the framebuffer.
	if has_alpha ~= had_alpha then set_scene_flags(has_alpha, false) end
	clear_framebuffer(obj.screen_w, obj.screen_h, has_alpha);
end

---"Inline scene" の状態を，入れ子状態のものも含めて全て強制終了する．条件に応じて警告メッセージを出力する．
---@param do_warn boolean 強制終了が実行されたならコンソールにメッセージを表示するかどうかを指定．`true` で出力する，`false` でしない．
local function quit_inline_scenes(do_warn)
	local stack = query_stack(get_current_scene());
	local info = stack:clear(do_warn);
	if info then set_scene_flags(info.has_alpha, info.is_nesting) end
end

---"Inline scene" や現在のシーンそのものの状態を取得する．
---@return integer ils_depth "Inline scene" の入れ子階層の深さ．"Inline scene" が開いていない状態だと `0`.
---@return boolean has_alpha フレームバッファのアルファチャンネルが有効な場合 `true`, 無効な場合 `false`.
---@return boolean is_nesting シーンオブジェクトやシーンチェンジなのでシーンのフレーム画像取得が行われている場合 `true`, それ以外は `false`.
local function tell_inline_scenes()
	local stack = query_stack(get_current_scene());
	return #stack.stack, get_scene_flags();
end

---指定した名前の "inline scene" に現在のオブジェクトの画像データを保存する．
---"Inline scene" に既存のデータは破棄される．
---@param name string "Inline scene" の名前．
---@param scene_idx integer|string|nil 対象のシーン番号，または独自の名前．`nil` の場合は現在オブジェクトのシーン番号．
local function save(name, scene_idx)
	local cache_name, metrics, _, _ = write_scene(name, scene_idx);

	obj.copybuffer(cache_name, "obj");
	if offscreen_drawn() then
		metrics:init();
		metrics.cx, metrics.cy = obj.cx - obj.getvalue("cx"), obj.cy - obj.getvalue("cy");
	else
		metrics.ox, metrics.oy, metrics.oz = obj.x + obj.ox, obj.y + obj.oy, obj.z + obj.oz;
		metrics.rx, metrics.ry, metrics.rz = obj.rx, obj.ry, obj.rz;
		metrics.cx, metrics.cy, metrics.cz = obj.cx, obj.cy, obj.cz;
		metrics.zoom, metrics.aspect = combine_aspect(obj.zoom * obj.getvalue("zoom") / 100, obj.aspect, obj.getvalue("aspect"));
		metrics.alpha = obj.alpha * obj.getvalue("alpha");
	end
	metrics.w, metrics.h = obj.getpixel();
end

---"Inline scene" を現在のオブジェクトとして読み込む．オプションで回転角や中心座標も復元する．
---@param name string "Inline scene" の名前を指定．
---@param restore_metrics boolean 相対座標や回転角度，回転中心などを復元するかどうかを指定．
---@param curr_frame boolean? 現在フレームで合成された "inline scene" のみを対象にするかどうかを指定．既定値は `false`.
---@param scene_idx integer|string|nil 対象のシーン番号，または独自の名前．`nil` の場合は現在オブジェクトのシーン番号．
---@return boolean success 正しく "inline scene" が読み込まれた場合は `true`, エラーなら `false`.
local function recall(name, restore_metrics, curr_frame, scene_idx)
	local cache_name, metrics, status, _ = read_scene(name, scene_idx);
	if not status or (curr_frame and status ~= "new") then return false end
	if not obj.copybuffer("obj", cache_name) then
		emit_warning(("[Inline Scene] %s, Frame: %d, Layer: %d\n\t")
			:format(scene_disp(get_current_scene()), get_current_frame(), obj.layer),
			([=[キャッシュ "%s" を読み込めませんでした．]=]
			..[=[patch.aul の設定 patch.aul.json で "switch" -> "shared_cache" が true になっているのを確認し，]=]
			..[=[AviUtl の設定で「キャッシュサイズ」を見直してみてください．]=]):format(cache_name));
		return false;
	end

	if restore_metrics then
		obj.ox, obj.oy, obj.oz = obj.ox + metrics.ox, obj.oy + metrics.oy, obj.oz + metrics.oz;
		obj.rx, obj.ry, obj.rz = obj.rx + metrics.rx, obj.ry + metrics.ry, obj.rz + metrics.rz;
		obj.cx, obj.cy, obj.cz = obj.cx + metrics.cx, obj.cy + metrics.cy, obj.cz + metrics.cz;
		obj.zoom, obj.aspect = combine_aspect(obj.zoom *  metrics.zoom, obj.aspect, metrics.aspect);
		obj.alpha = obj.alpha * metrics.alpha;
	end
	return true;
end

-- table for blend modes with their friendly names.
local blend_mode_value do
	local mode_table = {
		["通常"] = 0,
		["加算"] = 1,
		["減算"] = 2,
		["乗算"] = 3,
		["スクリーン"] = 4,
		["オーバーレイ"] = 5,
		["比較(明)"] = 6, ["比較（明）"] = 6,
		["比較(暗)"] = 7, ["比較（暗）"] = 7,
		["輝度"] = 8,
		["色差"] = 9,
		["陰影"] = 10,
		["明暗"] = 11,
		["差分"] = 12,
		alpha_add = "alpha_add",
		alpha_max = "alpha_max",
		alpha_sub = "alpha_sub",
		alpha_add2 = "alpha_add2",
	};
	function blend_mode_value(blend)
		local n = tonumber(blend);
		if not n then return mode_table[tostring(blend)];
		elseif n >= 0 and n % 1 == 0 then return n;
		else return nil end
	end
end

---指定した "Inline scene" と現在のオブジェクトを合成する．
---処理中に "tempbuffer" を上書きする．
---@param name string "Inline scene" の名前を指定．
---@param curr_frame boolean? 現在フレームで合成された "inline scene" のみを対象にするかどうかを指定．既定値は `false`.
---@param x number 合成の基準位置の X 座標．
---@param y number 合成の基準位置の Y 座標．
---@param zoom number 拡大率，等倍は `1.0`.
---@param alpha number 不透明度，完全不透明は `1.0`.
---@param angle number 回転角度，度数法で時計回りに正．
---@param loop boolean 画像ループをする場合は `true`, しない場合は `false`.
---@param back boolean 背面から合成する場合は `true`, 通常通り前面からの場合は `false`.
---@param blend integer|string|nil 合成モードを指定 `0`, `"加算"`, `"alpha_sub"` などが使える．`nil` だと通常の合成モード．
---@param scene_idx integer|string|nil 対象のシーン番号，または独自の名前．`nil` の場合は現在オブジェクトのシーン番号．
local function combine(name, curr_frame, x, y, zoom, alpha, angle, loop, back, blend, scene_idx)
	local cache_name, metrics, status, _ = read_scene(name, scene_idx);
	if not status or (curr_frame and status ~= "new") then return end

	local w, h = obj.getpixel();
	local blend_mode = blend_mode_value(blend) or 0;

	-- prepare the base.
	if back then
		obj.setoption("dst", "tmp", obj.getpixel());
		obj.copybuffer(name_cache_temp, "obj");
		obj.setoption("blend", 0);
	else
		obj.copybuffer("tmp", "obj");
		obj.setoption("dst", "tmp");
		obj.setoption("blend", blend_mode);
	end

	-- apply rotation and scaling.
	obj.copybuffer("obj", cache_name);
	local base_cx, base_cy = obj.getvalue("cx"), obj.getvalue("cy");
	local ox, oy, scale = x - obj.ox + obj.cx - base_cx, y - obj.oy + obj.cy - base_cy, zoom * metrics.zoom;
	if offscreen_drawn() then
		ox, oy = ox + obj.x - base_cx, oy + obj.y - base_cy;
	end
	local c, s = math.cos(math.pi / 180 * (angle + metrics.rz)), math.sin(math.pi / 180 * (angle + metrics.rz));
	ox, oy = ox + scale * (metrics.cx * c - metrics.cy * s), oy + scale * (metrics.cx * s + metrics.cy * c);

	-- apply loop.
	if loop then
		if scale < 0.5 then
			obj.effect("リサイズ", "拡大率", 100 * scale);
			scale = 1;
		end
		local W, H = obj.getpixel();
		if W == 0 or H == 0 then
			-- image is too small to tile.
			obj.copybuffer("obj", back and name_cache_temp or "tmp");
			return;
		end
		-- find the bounding box of the destination.
		local l, t, r, b = ox * c + oy * s, ox *-s + oy * c, (w * math.abs(c) + h * math.abs(s)) / 2, (w * math.abs(s) + h * math.abs(c)) / 2;
		l, t, r, b = -l - r, -t - b, -l + r, -t + b;
		l, t, r, b = l / (scale * W), t / (scale * H), r / (scale * W), b / (scale * H);

		-- adjust the position by lattice.
		local NX, NY = math.floor(0.5 * (1 + l + r)), math.floor(0.5 * (1 + t + b));
		ox, oy = ox + scale * (W * NX * c + H * NY *-s), oy + scale * (W * NX * s + H * NY * c);

		-- populate the image.
		NX, NY = 1 + 2 * math.ceil(math.max(NX - l, r - NX)), 1 + 2 * math.ceil(math.max(NY - t, b - NY));
		while NX > 1 or NY > 1 do
			local nx, ny = math.min(NX, 399), math.min(NY, 399);
			obj.effect("画像ループ", "横回数", nx, "縦回数", ny);
			NX, NY = 1 + 2 * math.ceil((NX / nx - 1) / 2), 1 + 2 * math.ceil((NY / ny - 1) / 2);
		end
	end

	-- then draw.
	obj.draw(ox, oy, 0, scale, alpha * metrics.alpha, 0, 0, angle + metrics.rz);

	-- draw the original image if drawing in the reversed order.
	if back then
		obj.copybuffer("obj", name_cache_temp);
		obj.setoption("blend", blend_mode);
		obj.draw();
	end

	-- load the desired image.
	obj.copybuffer("obj", "tmp");

	-- rewind the blend mode to normal.
	obj.setoption("blend", 0);
end

return {
	Begin = begin_inline_scene,
	End = end_inline_scene,
	Next = next_inline_scene,
	Quit = quit_inline_scenes,
	Status = tell_inline_scenes,

	save = save,
	recall = recall,
	combine = combine,

	read_cache = read_scene,
	write_cache = write_scene,
	clear_cache = clear_scenes,

	scene_frame = get_current_frame,
	scene_index = get_current_scene,
	offscreen_drawn = offscreen_drawn,
	is_playing = get_is_playing,

	bounding_box = bounding_box,
	combine_aspect = combine_aspect,
};
