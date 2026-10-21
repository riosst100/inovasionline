<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\LabelConfig;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class LabelConfigController extends Controller
{
    public function index(): JsonResponse
    {
        return ApiResponse::success($this->all(), 'Label retrieved successfully.');
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'items' => ['required', 'array', 'min:1'],
            'items.*.group' => ['required', 'string', 'max:40'],
            'items.*.key' => ['required', 'string', 'max:60'],
            'items.*.label' => ['required', 'string', 'max:60'],
            'items.*.color' => ['required', Rule::in(LabelConfig::COLORS)],
        ]);

        foreach ($data['items'] as $item) {
            // Only existing rows are editable; groups/keys are defined by the app.
            LabelConfig::query()
                ->where('group', $item['group'])
                ->where('key', $item['key'])
                ->update(['label' => trim($item['label']), 'color' => $item['color']]);
        }

        return ApiResponse::success($this->all(), 'Label berhasil disimpan.');
    }

    private function all(): array
    {
        return LabelConfig::query()->orderBy('group')->orderBy('sort_order')
            ->get(['group', 'key', 'label', 'color'])->toArray();
    }
}
