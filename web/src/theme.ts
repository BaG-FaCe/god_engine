import { createTheme, type Theme } from '@mui/material/styles';

/**
 * Platform theme.
 *
 * Kept in one place so every module looks identical without importing styles:
 * an industrial, low-chrome look with a traffic-light palette that the risk
 * components reuse (green / amber / red must stay recognisable across the app).
 */
export const RISK_COLORS = {
  low: '#2e7d32',
  medium: '#ed6c02',
  high: '#d32f2f',
  unknown: '#9e9e9e',
} as const;

export const theme: Theme = createTheme({
  palette: {
    mode: 'light',
    primary: { main: '#1f3a5f' },
    secondary: { main: '#0f7b6c' },
    success: { main: RISK_COLORS.low },
    warning: { main: RISK_COLORS.medium },
    error: { main: RISK_COLORS.high },
    background: { default: '#f4f6f8', paper: '#ffffff' },
  },
  shape: { borderRadius: 10 },
  typography: {
    fontFamily: [
      '"Inter"',
      'system-ui',
      '-apple-system',
      '"Segoe UI"',
      'Roboto',
      'sans-serif',
    ].join(','),
    h5: { fontWeight: 600 },
    h6: { fontWeight: 600 },
    subtitle2: { fontWeight: 600 },
  },
  components: {
    MuiCard: {
      defaultProps: { elevation: 0 },
      styleOverrides: { root: { border: '1px solid #e3e7ec' } },
    },
    MuiButton: { defaultProps: { disableElevation: true } },
    MuiTableCell: { styleOverrides: { head: { fontWeight: 600, whiteSpace: 'nowrap' } } },
  },
});
