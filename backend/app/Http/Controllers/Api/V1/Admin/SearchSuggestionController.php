<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\SearchLog;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SearchSuggestionController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'search' => ['nullable', 'string', 'max:100'],
            'source' => ['nullable', 'in:user,admin'],
        ]);

        $items = SearchLog::query()
            ->when($request->string('search')->toString(), fn ($q, $s) => $q->where('keyword', 'like', '%'.mb_strtolower(trim($s)).'%'))
            ->when($request->string('source')->toString(), fn ($q, $s) => $q->where('source', $s))
            ->orderByDesc('search_count')
            ->orderByDesc('last_searched_at')
            ->limit(500)
            ->get(['id', 'keyword', 'search_count', 'source', 'last_searched_at', 'created_at']);

        return ApiResponse::success($items, 'Search suggestions retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'keyword' => ['required', 'string', 'max:100'],
            'search_count' => ['required', 'integer', 'min:0', 'max:100000000'],
        ]);

        $keyword = mb_strtolower(trim($validated['keyword']));

        if ($keyword === '') {
            return ApiResponse::error('Query tidak boleh kosong.', [], 422);
        }

        if (SearchLog::where('keyword', $keyword)->exists()) {
            return ApiResponse::error('Query tersebut sudah ada.', [], 422);
        }

        $log = SearchLog::create([
            'keyword' => $keyword,
            'search_count' => $validated['search_count'],
            'source' => 'admin',
            'last_searched_at' => now(),
        ]);

        return ApiResponse::success($log, 'Search suggestion created successfully.', [], 201);
    }

    public function destroy(SearchLog $searchLog): JsonResponse
    {
        $searchLog->delete();

        return ApiResponse::success(null, 'Search suggestion deleted successfully.');
    }
}
