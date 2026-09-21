import { Box, Typography } from '@mui/material';
import type { ComponentType } from 'react';

function ComingSoon({ title, hint }: { title: string; hint: string }) {
  return (
    <Box sx={{ py: 4, textAlign: 'center' }}>
      <Typography variant="h6">{title}</Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
        {hint}
      </Typography>
    </Box>
  );
}

export function comingSoonModule(title: string, hint: string): ComponentType {
  return function ComingSoonModule() {
    return <ComingSoon title={title} hint={hint} />;
  };
}
