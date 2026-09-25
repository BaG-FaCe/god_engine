import { beforeEach, describe, expect, it } from 'vitest';
import { useNotificationUiStore } from './notification-store';

describe('useNotificationUiStore', () => {
  beforeEach(() => {
    useNotificationUiStore.setState({ panelOpen: false, lastSeenAt: null });
  });

  it('toggles the panel', () => {
    expect(useNotificationUiStore.getState().panelOpen).toBe(false);
    useNotificationUiStore.getState().togglePanel();
    expect(useNotificationUiStore.getState().panelOpen).toBe(true);
    useNotificationUiStore.getState().togglePanel();
    expect(useNotificationUiStore.getState().panelOpen).toBe(false);
  });

  it('records when the list was last seen', () => {
    expect(useNotificationUiStore.getState().lastSeenAt).toBeNull();
    useNotificationUiStore.getState().markSeen();
    expect(useNotificationUiStore.getState().lastSeenAt).toBeTruthy();
  });
});
