import { createFileRoute } from "@tanstack/react-router";

import { I7hqSettingsPanel } from "../components/settings/I7hqSettingsPanel";

function SettingsI7hqRoute() {
  return <I7hqSettingsPanel />;
}

export const Route = createFileRoute("/settings/i7hq")({
  component: SettingsI7hqRoute,
});
