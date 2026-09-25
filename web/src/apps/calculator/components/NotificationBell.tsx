import {
  Badge, Box, Button, Chip, Divider, IconButton, List, ListItemButton,
  ListItemText, Menu, Stack, Tooltip, Typography,
} from '@mui/material';
import { useMemo, useState } from 'react';
import { useCalculatorStore } from '../store/calculator-store';
import { useNotificationUiStore } from '../store/notification-store';
import {
  useAcknowledgeNotification, useDismissNotification, useNotifications,
  useReadAllNotifications,
} from '../api/notifications';
import type { RiskNotification } from '../api/risk';
import { ampelForLevel } from '../../../shared/components/RiskAmpel';

const SEVERITY_COLOR: Record<string, 'default' | 'info' | 'warning' | 'error'> = {
  low: 'default',
  medium: 'info',
  high: 'warning',
  critical: 'error',
};

/** Dependency-free relative timestamp ("vor 3 Min."). */
function timeAgo(value: string | null): string {
  if (!value) return '';
  const diffMs = Date.now() - new Date(value).getTime();
  const minutes = Math.max(0, Math.round(diffMs / 60_000));
  if (minutes < 1) return 'gerade eben';
  if (minutes < 60) return `vor ${minutes} Min.`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `vor ${hours} Std.`;
  const days = Math.round(hours / 24);
  return `vor ${days} Tg.`;
}

/**
 * Notification bell for the calculator module header (Update-Prompt Aufgabe 2).
 *
 * Shows the unread badge, a dropdown with the most recent risk notifications and
 * acknowledge/dismiss actions. Clicking an item deep-links to the material card
 * (materials tab + auto-expanded Lieferrisiko section).
 */
export function NotificationBell({ projectId }: { projectId?: string | null }) {
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const panelOpen = useNotificationUiStore((state) => state.panelOpen);
  const openPanel = useNotificationUiStore((state) => state.openPanel);
  const closePanel = useNotificationUiStore((state) => state.closePanel);
  const setTab = useCalculatorStore((state) => state.setTab);
  const focusMaterial = useCalculatorStore((state) => state.focusMaterial);

  const { data } = useNotifications(projectId);
  const acknowledge = useAcknowledgeNotification(projectId);
  const dismiss = useDismissNotification(projectId);
  const readAll = useReadAllNotifications(projectId);

  const notifications = useMemo(() => data?.data ?? [], [data]);
  const unreadCount = data?.meta.unreadCount ?? 0;

  const handleOpen = (event: React.MouseEvent<HTMLElement>) => {
    setAnchorEl(event.currentTarget);
    openPanel();
  };
  const handleClose = () => {
    setAnchorEl(null);
    closePanel();
  };

  const openMaterial = (notification: RiskNotification) => {
    if (notification.materialId) {
      setTab('materials');
      focusMaterial(notification.materialId);
    }
    handleClose();
  };

  return (
    <>
      <Tooltip title="Lieferrisiko-Benachrichtigungen">
        <IconButton color="inherit" onClick={handleOpen} aria-label="Benachrichtigungen">
          <Badge badgeContent={unreadCount} color="error" invisible={unreadCount === 0}>
            <Box component="span" sx={{ fontSize: 20, lineHeight: 1 }} aria-hidden>🔔</Box>
          </Badge>
        </IconButton>
      </Tooltip>

      <Menu
        anchorEl={anchorEl}
        open={Boolean(anchorEl) && panelOpen}
        onClose={handleClose}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
        transformOrigin={{ vertical: 'top', horizontal: 'right' }}
        slotProps={{ paper: { sx: { width: 400, maxWidth: '92vw' } } }}
      >
        <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ px: 2, py: 1 }}>
          <Typography variant="subtitle2">Kritische Lieferrisiken</Typography>
          <Button size="small" disabled={unreadCount === 0} onClick={() => readAll.mutate()}>
            Alle gelesen
          </Button>
        </Stack>
        <Divider />
        {notifications.length === 0 ? (
          <Typography variant="body2" color="text.secondary" sx={{ px: 2, py: 3, textAlign: 'center' }}>
            Keine offenen Meldungen.
          </Typography>
        ) : (
          <List dense sx={{ maxHeight: 420, overflow: 'auto' }}>
            {notifications.map((notification) => (
              <NotificationItem
                key={notification.id}
                notification={notification}
                onOpen={() => openMaterial(notification)}
                onAcknowledge={() => acknowledge.mutate(notification.id)}
                onDismiss={() => dismiss.mutate(notification.id)}
              />
            ))}
          </List>
        )}
      </Menu>
    </>
  );
}

function NotificationItem({
  notification, onOpen, onAcknowledge, onDismiss,
}: {
  notification: RiskNotification;
  onOpen: () => void;
  onAcknowledge: () => void;
  onDismiss: () => void;
}) {
  const ampel = ampelForLevel(notification.severity);
  const symbol = ampel === 'red' ? '🔴' : ampel === 'yellow' ? '🟡' : ampel === 'green' ? '🟢' : '⚪';

  return (
    <ListItemButton onClick={onOpen} alignItems="flex-start" divider>
      <ListItemText
        primary={
          <Typography component="span" variant="body2"
            fontWeight={notification.status === 'unread' ? 600 : 400}>
            {symbol} {notification.title}
          </Typography>
        }
        secondary={
          <Box>
            {notification.body && (
              <Typography variant="caption" color="text.secondary" component="div" noWrap>
                {notification.body}
              </Typography>
            )}
            <Stack direction="row" spacing={1} alignItems="center" sx={{ mt: 0.5 }}>
              <Chip size="small" label={notification.severity}
                color={SEVERITY_COLOR[notification.severity]} variant="outlined" />
              <Typography variant="caption" color="text.secondary">
                {timeAgo(notification.createdAt)}
              </Typography>
              <Box sx={{ flexGrow: 1 }} />
              {notification.status !== 'dismissed' && (
                <>
                  <Button size="small" onClick={(e) => { e.stopPropagation(); onAcknowledge(); }}>
                    Gesehen
                  </Button>
                  <Button size="small" color="inherit"
                    onClick={(e) => { e.stopPropagation(); onDismiss(); }}>
                    Verwerfen
                  </Button>
                </>
              )}
            </Stack>
          </Box>
        }
      />
    </ListItemButton>
  );
}
