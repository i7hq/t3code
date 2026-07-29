import { useClientSettings, useUpdateClientSettings } from "../../hooks/useSettings";
import { Switch } from "../ui/switch";
import { SettingsPageContainer, SettingsRow, SettingsSection } from "./settingsLayout";

// Fork-local (i7hq) options. Everything in this panel is specific to the
// i7hq fork and intentionally kept out of the upstream settings sections so
// rebases only ever conflict on the sidebar nav entry.
export function I7hqSettingsPanel() {
  const showEnvironmentStateDir = useClientSettings((settings) => settings.showEnvironmentStateDir);
  const updateSettings = useUpdateClientSettings();

  return (
    <SettingsPageContainer>
      <SettingsSection title="i7hq">
        <SettingsRow
          title="Show environment state directories"
          description="Label remote environments with their state directory (e.g. ~/.t3/userdata) instead of their environment id, so multiple environments on one machine are distinguishable. Environments running a server without state directory support keep showing their id."
          control={
            <Switch
              checked={showEnvironmentStateDir}
              onCheckedChange={(checked) =>
                updateSettings({ showEnvironmentStateDir: Boolean(checked) })
              }
              aria-label="Show environment state directories"
            />
          }
        />
      </SettingsSection>
    </SettingsPageContainer>
  );
}
