<script>
  import { gettext, ngettext } from '../translations';

  export let items = [];
  export let total = 0;
</script>

<div class="shopping-cart">
  <h2>{gettext("Shopping Cart")}</h2>

  {#if items.length === 0}
    <p class="empty">{gettext("Your cart is empty")}</p>
  {:else}
    <div class="cart-items">
      <p>{ngettext("%{n} item in cart", "%{n} items in cart", items.length)}</p>

      <div class="total">
        {gettext("Total: %{amount}", { amount: total })}
      </div>

      <button>{gettext("Checkout")}</button>
      <button>{gettext("Continue Shopping")}</button>
    </div>
  {/if}

  <div class="help">
    <a href="/help">{gettext("Need help?")}</a>
  </div>
</div>
