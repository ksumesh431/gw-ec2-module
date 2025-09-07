# ansible/vars_plugins/client_loader.py
import os
import yaml
from ansible.plugins.vars import BaseVarsPlugin
from ansible.errors import AnsibleError
from ansible.utils.display import Display
from ansible.utils.vars import combine_vars

display = Display()

class VarsModule(BaseVarsPlugin):
    NAME = 'client_loader'

    def get_vars(self, loader, path, entities, cache=True):
        super(VarsModule, self).get_vars(loader, path, entities)

        # --- DEBUGGING ---
        display.warning(">>>> [DEBUG] client_loader plugin is now running.")

        client_id = self._options.get('extra_vars', {}).get('client_id')
        if not client_id:
            display.warning(">>>> [DEBUG] No client_id found in extra_vars. Plugin is exiting.")
            return {}
        
        display.warning(f">>>> [DEBUG] Found client_id: {client_id}")

        # --- THE CRITICAL PATH CALCULATION ---
        # ansible.cfg is inside 'ansible/', so this plugin file is also inside 'ansible/'.
        # We need to find env_vars.yml at the project root, which is two levels up from this file's location.
        # __file__ is the absolute path to this very python script.
        plugin_dir = os.path.dirname(os.path.realpath(__file__))
        project_root = os.path.abspath(os.path.join(plugin_dir, '..')) # Go up from ansible/vars_plugins to ansible/, then up to the root.
        config_path = os.path.join(project_root, 'env_vars.yml')
        
        display.warning(f">>>> [DEBUG] Plugin file is at: {__file__}")
        display.warning(f">>>> [DEBUG] Calculated project root: {project_root}")
        display.warning(f">>>> [DEBUG] Final config path to env_vars.yml: {config_path}")

        if not os.path.exists(config_path):
            display.error(f">>>> [FATAL] env_vars.yml NOT FOUND at calculated path: {config_path}")
            return {}

        try:
            with open(config_path, 'r') as f:
                env_config = yaml.safe_load(f)
        except Exception as e:
            raise AnsibleError(f"Error loading or parsing env_vars.yml: {e}")

        defaults = env_config.get('defaults', {}).get('ansible_vars', {})
        client_vars = env_config.get('clients', {}).get(client_id, {}).get('ansible_vars', {})

        if not client_vars and client_id not in env_config.get('clients', {}):
             raise AnsibleError(f"Client ID '{client_id}' not found in env_vars.yml")

        final_vars = combine_vars(defaults, client_vars)
        display.warning(f">>>> [DEBUG] Final merged variables being injected: {final_vars}")

        return final_vars