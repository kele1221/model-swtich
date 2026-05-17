import { render, waitFor } from "@testing-library/react";
import type React from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { EditProviderDialog } from "@/components/providers/EditProviderDialog";
import type { Provider } from "@/types";

const apiMocks = vi.hoisted(() => ({
  getCurrent: vi.fn(),
  getLiveProviderSettings: vi.fn(),
  getLiveProvider: vi.fn(),
}));

const formMocks = vi.hoisted(() => ({
  providerForm: vi.fn(),
}));

vi.mock("@/lib/api", () => ({
  providersApi: {
    getCurrent: apiMocks.getCurrent,
  },
  vscodeApi: {
    getLiveProviderSettings: apiMocks.getLiveProviderSettings,
  },
  openclawApi: {
    getLiveProvider: apiMocks.getLiveProvider,
  },
}));

vi.mock("@/components/common/FullScreenPanel", () => ({
  FullScreenPanel: ({
    children,
    footer,
  }: {
    children: React.ReactNode;
    footer?: React.ReactNode;
  }) => (
    <div>
      {children}
      {footer}
    </div>
  ),
}));

vi.mock("@/components/providers/forms/ProviderForm", () => ({
  ProviderForm: (props: unknown) => {
    formMocks.providerForm(props);
    return <form id="provider-form" />;
  },
}));

describe("EditProviderDialog", () => {
  const provider: Provider = {
    id: "cn-p1",
    name: "Claude CN Provider",
    settingsConfig: {
      env: {
        ANTHROPIC_BASE_URL: "https://db.claude-cn.example",
        ANTHROPIC_DEFAULT_SONNET_MODEL: "db-model",
      },
    },
    category: "custom",
    createdAt: 1,
  };

  beforeEach(() => {
    apiMocks.getCurrent.mockResolvedValue("cn-p1");
    apiMocks.getLiveProviderSettings.mockResolvedValue({
      env: {
        ANTHROPIC_BASE_URL: "https://stale-live.example",
        ANTHROPIC_DEFAULT_SONNET_MODEL: "stale-model",
      },
    });
  });

  it("uses the database provider config for Claude CN instead of stale live settings", async () => {
    render(
      <EditProviderDialog
        open
        provider={provider}
        onOpenChange={vi.fn()}
        onSubmit={vi.fn()}
        appId="claude-cn"
      />,
    );

    await waitFor(() => expect(formMocks.providerForm).toHaveBeenCalled());

    const latestProps =
      formMocks.providerForm.mock.calls[
        formMocks.providerForm.mock.calls.length - 1
      ][0];

    expect(apiMocks.getCurrent).not.toHaveBeenCalled();
    expect(apiMocks.getLiveProviderSettings).not.toHaveBeenCalled();
    expect(latestProps.initialData.settingsConfig).toEqual(
      provider.settingsConfig,
    );
  });
});
