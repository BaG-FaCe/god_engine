import { Box, Typography } from '@mui/material';
import type { ReactNode } from 'react';

export function EmptyState({
  title,
  hint,
  action,
}: {
  title: string;
  hint?: string;
  action?: ReactNode;
}) {
  return (
    <Box
      sx={{
        border: '1px dashed #cfd6dd',
        borderRadius: 2,
        px: 3,
        py: 4,
        textAlign: 'center',
        bgcolor: 'background.paper',
      }}
    >
      <Typography variant="subtitle1">{title}</Typography>
      {hint ? (
        <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
          {hint}
        </Typography>
      ) : null}
      {action ? <Box sx={{ mt: 2 }}>{action}</Box> : null}
    </Box>
  );
}
