# ansible/vars_plugins/client_loader.py
import os
import yaml
from ansible.plugins.vars import BaseVarsPlugin
from ansible.errors import AnsibleError
from ansible.utils.display import Display
from ansible.utils.vars import combine_vars

display = Display()


class VarsModule(BaseVarsPlugin):
    NAME = "client_loader"

    def get_vars(self, loader, path, entities, cache=True):
        super(VarsModule, self).get_vars(loader, path, entities)
        data = {}
        client_id = self._options.get("extra_vars", {}).get("client_id")

        if not client_id:
            return {}

        # Get the directory where the ansible command is being run
        basedir = self._options.get("basedir")

        # Construct the path to env_vars.yml at the repo root, which is one level up
        config_path = os.path.join(basedir, "../env_vars.yml")

        if not os.path.exists(config_path):
            display.warning(
                f"Client loader plugin could not find env_vars.yml at {config_path}"
            )
            return {}

        try:
            with open(config_path, "r") as f:
                env_config = yaml.safe_load(f)
        except Exception as e:
            raise AnsibleError(f"Error loading or parsing env_vars.yml: {e}")

        defaults = env_config.get("defaults", {}).get("ansible_vars", {})
        client_vars = (
            env_config.get("clients", {}).get(client_id, {}).get("ansible_vars", {})
        )

        if not client_vars and client_id not in env_config.get("clients", {}):
            raise AnsibleError(f"Client ID '{client_id}' not found in env_vars.yml")

        final_vars = combine_vars(defaults, client_vars)
        return final_vars
