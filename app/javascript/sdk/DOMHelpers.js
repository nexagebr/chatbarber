import { SDK_CSS } from './sdk.js';
import { IFrameHelper } from './IFrameHelper';

export const loadCSS = () => {
  const css = document.createElement('style');
  css.innerHTML = `${SDK_CSS}`;
  css.id = 'cw-widget-styles';
  css.dataset.turboPermanent = true;
  document.body.appendChild(css);
};

// This is a method specific to Turbo
// The body replacing strategy removes Chatwoot styles
// as well as the widget, this help us get it back
export const restoreElement = (id, newBody) => {
  const element = document.getElementById(id);
  const newElement = newBody.querySelector(`#${id}`);

  if (element && !newElement) {
    newBody.appendChild(element);
  }
};

export const restoreWidgetInDOM = newBody => {
  restoreElement('cw-bubble-holder', newBody);
  restoreElement('cw-widget-holder', newBody);
  restoreElement('cw-widget-styles', newBody);
};

export const addClasses = (elm, classes) => {
  elm.classList.add(...classes.split(' '));
};

export const toggleClass = (elm, classes) => {
  elm.classList.toggle(classes);
};

export const removeClasses = (elm, classes) => {
  elm.classList.remove(...classes.split(' '));
};

const TRACKING_PARAMS = [
  'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
  'gclid', 'fbclid', 'ttclid', 'msclkid',
];
const SESSION_KEY = 'cw_landing_url';

// Persist the landing URL (with tracking params) in sessionStorage on first load only.
// This survives SPA navigation so gclid/utm are still available when the chat opens.
const persistLandingUrl = url => {
  try {
    if (sessionStorage.getItem(SESSION_KEY)) return; // already captured — keep first-touch
    const parsed = new URL(url);
    const hasTracking = TRACKING_PARAMS.some(p => parsed.searchParams.has(p));
    if (hasTracking) {
      sessionStorage.setItem(SESSION_KEY, url);
    }
  } catch (_) {
    // ignore invalid URLs or environments without sessionStorage
  }
};

export const getLandingUrl = () => {
  try {
    return sessionStorage.getItem(SESSION_KEY) || window.referrerURL || '';
  } catch (_) {
    return window.referrerURL || '';
  }
};

export const onLocationChange = ({ referrerURL, referrerHost }) => {
  IFrameHelper.events.onLocationChange({
    referrerURL,
    referrerHost,
  });
};

export const onLocationChangeListener = () => {
  let oldHref = document.location.href;
  const referrerHost = document.location.host;
  const config = {
    childList: true,
    subtree: true,
  };
  // Capture tracking params from the initial landing URL before SPA navigation changes it
  persistLandingUrl(oldHref);
  onLocationChange({
    referrerURL: oldHref,
    referrerHost,
  });

  const bodyList = document.querySelector('body');
  const observer = new MutationObserver(mutations => {
    mutations.forEach(() => {
      if (oldHref !== document.location.href) {
        oldHref = document.location.href;
        onLocationChange({
          referrerURL: oldHref,
          referrerHost,
        });
      }
    });
  });

  observer.observe(bodyList, config);
};
