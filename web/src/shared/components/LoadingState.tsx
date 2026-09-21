import { Box, CircularProgress, Typography } from '@mui/material';

export function LoadingState({ label = 'Wird geladen …' }: { label?: string }) {
  return (
    <Box
      role="status"
      aria-label={label}
      sx={{ display: 'flex', alignItems: 'center', gap: 2, py: 4, justifyContent: 'center' }}
    >
      <CircularProgress size={24} />
      <Typography variant="body2" color="text.secondary">
        {label}
      </Typography>
    </Box>
  );
}
