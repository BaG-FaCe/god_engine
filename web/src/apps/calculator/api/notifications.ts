import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { riskApi } from './risk';

/**
 * TanStack Query hooks for the in-app risk notifications.
 *
 * The list is polled on an interval (`refetchInterval`); a later move to
 * ActionCable only has to replace `queryFn` with a subscription that pushes into
 * the same cache key, so the bell component stays untouched.
 */
const KEYS = {
  root: ['calculator'] as const,
  notifications: (projectId?: string | null) =>
    [...KEYS.root, 'notifications', projectId ?? 'none'] as const,
};

export const NOTIFICATION_POLL_INTERVAL_MS = 30_000;

export function useNotifications(projectId?: string | null) {
  return useQuery({
    queryKey: KEYS.notifications(projectId),
    queryFn: () => riskApi.notifications(projectId ?? undefined),
    refetchInterval: NOTIFICATION_POLL_INTERVAL_MS,
  });
}

export function useAcknowledgeNotification(projectId?: string | null) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => riskApi.acknowledgeNotification(id),
    onSuccess: () => void client.invalidateQueries({ queryKey: KEYS.notifications(projectId) }),
  });
}

export function useDismissNotification(projectId?: string | null) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => riskApi.dismissNotification(id),
    onSuccess: () => void client.invalidateQueries({ queryKey: KEYS.notifications(projectId) }),
  });
}

export function useReadNotification(projectId?: string | null) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => riskApi.readNotification(id),
    onSuccess: () => void client.invalidateQueries({ queryKey: KEYS.notifications(projectId) }),
  });
}

export function useReadAllNotifications(projectId?: string | null) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: () => riskApi.readAllNotifications(projectId ?? undefined),
    onSuccess: () => void client.invalidateQueries({ queryKey: KEYS.notifications(projectId) }),
  });
}
