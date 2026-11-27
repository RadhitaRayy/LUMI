<?php

namespace App\Services\Agent\Tools;

use App\Enums\Role;
use App\Llm\LlmToolDefinition;
use App\Llm\LlmToolParam;
use App\Models\AppSetting;
use App\Models\ToolPolicy;
use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Throwable;

class WebSearchTool implements AgentTool
{
    public function name(): string
    {
        return 'web_search';
    }

    public function label(): string
    {
        return __('Web search');
    }

    public function description(): string
    {
        return __('Search the web for up-to-date information.');
    }

    public function defaultMode(Role $role): string
    {
        return ToolPolicy::MODE_AUTO;
    }

    public function isAvailable(): bool
    {
        $settings = AppSetting::current();

        return $settings->web_search_enabled
            && is_string($settings->web_search_driver) && $settings->web_search_driver !== ''
            && is_string($settings->web_search_api_key) && trim($settings->web_search_api_key) !== '';
    }

    public function definition(): LlmToolDefinition
    {
        return new LlmToolDefinition(
            name: $this->name(),
            description: 'Search the web for current information and return concise source snippets.',
            parameters: [
                new LlmToolParam('query', 'string', 'Search query.'),
            ],
        );
    }

    public function execute(User $user, array $arguments): ToolExecutionResult
    {
        $query = is_string($arguments['query'] ?? null) ? trim($arguments['query']) : '';
        if ($query === '') {
            return ToolExecutionResult::error('Search query is required.', __('Missing query'));
        }

        $settings = AppSetting::current();
        $apiKey = trim((string) $settings->web_search_api_key);
        $driver = (string) $settings->web_search_driver;

        if (! $settings->web_search_enabled || $apiKey === '') {
            return ToolExecutionResult::error('Web search is not configured.', __('Web search disabled'));
        }

        try {
            $results = match ($driver) {
                'tavily' => $this->searchTavily($query, $apiKey),
                'brave' => $this->searchBrave($query, $apiKey),
                default => null,
            };
        } catch (Throwable) {
            return ToolExecutionResult::error('Web search provider failed to respond.', __('Search failed'));
        }

        if ($results === null) {
            return ToolExecutionResult::error("Unsupported web search driver: {$driver}.", __('Invalid search driver'));
        }

        if ($results === []) {
            return ToolExecutionResult::ok("No web results found for \"{$query}\".", __('No web results'));
        }

        $lines = array_map(
            fn (array $r): string => "- {$r['title']} ({$r['url']})\n  {$r['snippet']}",
            $results,
        );

        return ToolExecutionResult::ok(
            "Untrusted web search snippets for \"{$query}\":\n".implode("\n", $lines),
            trans_choice(':count result|:count results', count($results), ['count' => count($results)]),
        );
    }

    /**
     * Verifies a Web Search provider credential from Lumi Console with a minimal query.
     *
     * @return array{ok: bool, message: string}
     */
    public function testConnection(string $driver, string $apiKey): array
    {
        $key = trim($apiKey);
        if ($key === '') {
            return ['ok' => false, 'message' => 'API key belum diisi.'];
        }

        try {
            match ($driver) {
                'tavily' => $this->searchTavily('Lumi assistant', $key),
                'brave' => $this->searchBrave('Lumi assistant', $key),
                default => throw new \InvalidArgumentException("Unsupported driver: {$driver}"),
            };

            return ['ok' => true, 'message' => 'Koneksi Web Search berhasil.'];
        } catch (Throwable $e) {
            return ['ok' => false, 'message' => 'Koneksi Web Search gagal: '.Str::limit($e->getMessage(), 140)];
        }
    }

    /**
     * @return list<array{title: string, url: string, snippet: string}>
     */
    private function searchTavily(string $query, string $apiKey): array
    {
        $response = Http::timeout(10)->post('https://api.tavily.com/search', [
            'api_key' => $apiKey,
            'query' => $query,
            'max_results' => 5,
            'search_depth' => 'basic',
        ])->throw();

        $raw = $response->json('results');
        if (! is_array($raw)) {
            return [];
        }

        $out = [];
        foreach (array_slice($raw, 0, 5) as $item) {
            if (! is_array($item)) {
                continue;
            }
            $out[] = [
                'title' => Str::limit(trim((string) ($item['title'] ?? 'Result')), 120),
                'url' => trim((string) ($item['url'] ?? '')),
                'snippet' => Str::limit(Str::squish((string) ($item['content'] ?? '')), 260),
            ];
        }

        return $out;
    }

    /**
     * @return list<array{title: string, url: string, snippet: string}>
     */
    private function searchBrave(string $query, string $apiKey): array
    {
        $response = Http::timeout(10)
            ->withHeaders(['X-Subscription-Token' => $apiKey, 'Accept' => 'application/json'])
            ->get('https://api.search.brave.com/res/v1/web/search', [
                'q' => $query,
                'count' => 5,
            ])->throw();

        $raw = $response->json('web.results');
        if (! is_array($raw)) {
            return [];
        }

        $out = [];
        foreach (array_slice($raw, 0, 5) as $item) {
            if (! is_array($item)) {
                continue;
            }
            $out[] = [
                'title' => Str::limit(trim((string) ($item['title'] ?? 'Result')), 120),
                'url' => trim((string) ($item['url'] ?? '')),
                'snippet' => Str::limit(Str::squish((string) ($item['description'] ?? '')), 260),
            ];
        }

        return $out;
    }
}
