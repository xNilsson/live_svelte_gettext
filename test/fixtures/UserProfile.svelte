<script lang="ts">
  import { gettext, ngettext } from '../translations';

  export let username: string;
  export let itemCount: number = 0;
  export let step: number = 1;
  export let totalSteps: number = 5;
</script>

<div class="user-profile">
  <h1>{gettext("User Profile")}</h1>

  <div class="welcome">
    <p>{gettext("Welcome back, %{name}!", { name: username })}</p>
  </div>

  <div class="stats">
    <span>{ngettext("%{count} item", "%{count} items", itemCount)}</span>
  </div>

  <div class="progress">
    <p>{gettext("Step %{current} of %{total}", { current: step, total: totalSteps })}</p>
  </div>

  <button class="save-btn">
    {gettext("Save Changes")}
  </button>

  <button class="cancel-btn">
    {gettext('Cancel')}
  </button>

  <!-- This should not be extracted: {gettext("Hidden Comment")} -->

  <div class="actions">
    {gettext("Edit")} | {gettext("Delete")} | {gettext("Share")}
  </div>

  <footer>
    <p>{gettext('Copyright © 2025')}</p>
    <p>{gettext("All rights reserved")}</p>
  </footer>
</div>
