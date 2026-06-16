import { frontendURL } from '../../../../helper/URLHelper';
import Index from './Index.vue';
import AppearanceIndex from './AppearanceIndex.vue';
import SettingsWrapper from '../SettingsWrapper.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/general'),
      meta: {
        permissions: ['administrator'],
      },
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'general_settings_index',
          component: Index,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/settings/appearance'),
      meta: {
        permissions: ['administrator'],
      },
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'appearance_settings_index',
          component: AppearanceIndex,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
