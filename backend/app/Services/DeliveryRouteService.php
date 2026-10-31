<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Road route from the courier to the buyer for the tracking map, via OpenRouteService (free tier,
 * about 2,000 routes a day). One route is fetched per order and reused while the courier follows
 * it: each request only cuts off the part already driven. A new route is fetched when it gets old
 * or the courier strays from it, so a whole delivery costs a handful of calls, not one per GPS ping.
 */
class DeliveryRouteService
{
    private const BASE_URL = 'https://api.openrouteservice.org/v2/directions/driving-car/geojson';

    /** Fetch a fresh route after this long, so the remaining time doesn't drift too far from reality. */
    private const MAX_AGE_SECONDS = 300;

    /** The courier is this far from every point of the cached route: they took another way. */
    private const OFF_ROUTE_METERS = 250;

    /** After a failed call, wait this long before asking again, so an outage doesn't burn the quota. */
    private const FAILURE_BACKOFF_SECONDS = 120;

    /**
     * The rest of the route, or null when no API key is configured or the service is unavailable
     * (the app then draws a straight line).
     *
     * @return array{points: list<array{float, float}>, distance_m: int, duration_s: int}|null
     */
    public function remaining(string $orderId, float $fromLat, float $fromLng, float $toLat, float $toLng): ?array
    {
        $key = config('services.openrouteservice.key');
        if (! $key) {
            return null;
        }

        $cacheKey = "delivery_route:{$orderId}";
        $cached = Cache::get($cacheKey);
        $sameDestination = $cached !== null && $cached['to'] === [$toLat, $toLng];

        if ($sameDestination && $cached['route'] === null) {
            return null; // still backing off after a failure
        }

        if ($sameDestination && now()->timestamp - $cached['at'] < self::MAX_AGE_SECONDS) {
            $rest = $this->trim($cached['route'], $fromLat, $fromLng);
            if ($rest !== null) {
                return $rest;
            }
        }

        $route = $this->fetch($key, $fromLat, $fromLng, $toLat, $toLng);
        Cache::put(
            $cacheKey,
            ['to' => [$toLat, $toLng], 'at' => now()->timestamp, 'route' => $route],
            $route === null ? self::FAILURE_BACKOFF_SECONDS : self::MAX_AGE_SECONDS * 4,
        );

        return $route === null ? null : $this->trim($route, $fromLat, $fromLng);
    }

    /** @return array{points: list<array{float, float}>, distance_m: int, duration_s: int}|null */
    private function fetch(string $key, float $fromLat, float $fromLng, float $toLat, float $toLng): ?array
    {
        try {
            $feature = Http::timeout(8)
                ->withHeaders(['Authorization' => $key])
                ->post(self::BASE_URL, ['coordinates' => [[$fromLng, $fromLat], [$toLng, $toLat]]])
                ->throw()
                ->json('features.0');
        } catch (Throwable $e) {
            report($e);

            return null;
        }

        $coordinates = $feature['geometry']['coordinates'] ?? [];
        if (count($coordinates) < 2) {
            return null;
        }

        return [
            // GeoJSON is [lng, lat]; the app wants [lat, lng].
            'points' => array_map(fn (array $c) => [(float) $c[1], (float) $c[0]], $coordinates),
            'distance_m' => (int) round($feature['properties']['summary']['distance'] ?? 0),
            'duration_s' => (int) round($feature['properties']['summary']['duration'] ?? 0),
        ];
    }

    /**
     * Drops the part before the route point nearest the courier and scales distance and duration
     * to what is left. Null when the courier is off the route.
     */
    private function trim(array $route, float $lat, float $lng): ?array
    {
        $points = $route['points'];
        $nearest = 0;
        $nearestMeters = INF;
        foreach ($points as $i => [$pLat, $pLng]) {
            $meters = $this->meters($lat, $lng, $pLat, $pLng);
            if ($meters < $nearestMeters) {
                $nearestMeters = $meters;
                $nearest = $i;
            }
        }

        if ($nearestMeters > self::OFF_ROUTE_METERS) {
            return null;
        }

        $total = $this->length($points);
        $rest = array_slice($points, $nearest);
        $left = $this->length($rest);
        $share = $total > 0 ? $left / $total : 1;

        return [
            'points' => $rest,
            'distance_m' => (int) round($route['distance_m'] * $share),
            'duration_s' => (int) round($route['duration_s'] * $share),
        ];
    }

    private function length(array $points): float
    {
        $sum = 0.0;
        for ($i = 1, $n = count($points); $i < $n; $i++) {
            $sum += $this->meters($points[$i - 1][0], $points[$i - 1][1], $points[$i][0], $points[$i][1]);
        }

        return $sum;
    }

    private function meters(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return 6371000 * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
