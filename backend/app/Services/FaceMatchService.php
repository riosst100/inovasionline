<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

class FaceMatchService
{
    /**
     * Detect faces in a stored image and return their embeddings.
     *
     * @return array<int, array{bbox: array<int, float>, det_score: float, embedding: array<int, float>}>
     */
    public function embed(string $storagePath, string $disk = 'public'): array
    {
        $contents = Storage::disk($disk)->get($storagePath);

        $response = Http::withHeaders([
            'X-Api-Key' => config('services.potocandid.api_key'),
        ])
            ->timeout(30)
            ->attach('image', $contents, basename($storagePath))
            ->post(config('services.potocandid.base_url').'/embeddings');

        if (! $response->successful()) {
            throw new RuntimeException('Failed to compute face embeddings: '.$response->body());
        }

        return $response->json('faces', []);
    }

    /**
     * Compare a probe embedding against a list of candidate embeddings.
     *
     * @param  array<int, float>  $probeEmbedding
     * @param  array<int, array{id: string, embedding: array<int, float>}>  $candidates
     * @return array<int, array{id: string, score: float}>
     */
    public function compare(array $probeEmbedding, array $candidates, ?float $threshold = null): array
    {
        $response = Http::withHeaders([
            'X-Api-Key' => config('services.potocandid.api_key'),
        ])
            ->timeout(30)
            ->post(config('services.potocandid.base_url').'/compare', [
                'probe_embedding' => $probeEmbedding,
                'candidates' => $candidates,
                'threshold' => $threshold,
            ]);

        if (! $response->successful()) {
            throw new RuntimeException('Failed to compare face embeddings: '.$response->body());
        }

        return $response->json('matches', []);
    }
}
