import { renderHook, waitFor } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { useProviderCategory } from "@/components/providers/forms/hooks/useProviderCategory";
import { providerPresets } from "@/config/claudeProviderPresets";

describe("useProviderCategory", () => {
  it("uses Claude presets for Claude CN", async () => {
    const presetIndex = providerPresets.findIndex(
      (preset) => preset.category && preset.category !== "official",
    );

    expect(presetIndex).toBeGreaterThanOrEqual(0);

    const { result } = renderHook(() =>
      useProviderCategory({
        appId: "claude-cn",
        selectedPresetId: `claude-${presetIndex}`,
        isEditMode: false,
      }),
    );

    await waitFor(() => {
      expect(result.current.category).toBe(
        providerPresets[presetIndex].category,
      );
    });
  });
});
