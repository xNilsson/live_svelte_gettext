<script>
  import { gettext } from '../translations';

  export let errorType = 'unknown';
</script>

<div class="error-container">
  {#if errorType === 'network'}
    <p>{gettext("Network connection failed")}</p>
  {:else if errorType === 'auth'}
    <p>{gettext("Authentication error - please log in again")}</p>
  {:else if errorType === 'validation'}
    <p>{gettext("Please check your input")}</p>
  {:else}
    <p>{gettext("An unknown error occurred")}</p>
  {/if}

  <!-- Test escaped quotes -->
  <p>{gettext("It's working!")}</p>
  <p>{gettext("The \"system\" is operational")}</p>

  <!-- Test special characters -->
  <p>{gettext("Path: C:\\Users\\Documents")}</p>
</div>
