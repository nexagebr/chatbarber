import { frontendURL } from '../../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';
import ProductsLayout from './ProductsLayout.vue';
import ProductsIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/products'),
      component: ProductsLayout,
      children: [
        {
          path: '',
          name: 'products_list',
          meta: { permissions: [...ROLES] },
          component: ProductsIndex,
        },
      ],
    },
  ],
};
