import { renderHook, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { useBaseUrlState } from "@/components/providers/forms/hooks/useBaseUrlState";

describe("useBaseUrlState", () => {
  it("hydrates Claude CN base URL from settings config", async () => {
    const settingsConfig = JSON.stringify({
      env: {
        ANTHROPIC_BASE_URL: "https://claude-cn.example.com",
      },
    });

    const { result } = renderHook(() =>
      useBaseUrlState({
        appType: "claude-cn",
        category: "custom",
        settingsConfig,
        onSettingsConfigChange: vi.fn(),
      }),
    );

    await waitFor(() => {
      expect(result.current.baseUrl).toBe("https://claude-cn.example.com");
    });
  });
});
