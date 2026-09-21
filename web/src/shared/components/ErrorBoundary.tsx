import { Alert, AlertTitle, Box, Button, Stack, Typography } from '@mui/material';
import { Component, type ErrorInfo, type ReactNode } from 'react';
import { errorMessage } from '../lib/errors';

interface Props {
  children: ReactNode;
}

interface State {
  error: unknown;
}

/**
 * Module level error boundary.
 *
 * A failing module must never take the shell down: the user keeps the navigation
 * and can switch to another module while the error stays visible and retryable.
 */
export class ErrorBoundary extends Component<Props, State> {
  override state: State = { error: null };

  static getDerivedStateFromError(error: unknown): State {
    return { error };
  }

  override componentDidCatch(error: Error, info: ErrorInfo): void {
    // Kept intentionally small: the backend already logs provider/domain errors,
    // this is only for rendering problems in the SPA.
    console.error('[god-engine] module error', error, info.componentStack);
  }

  private readonly reset = () => this.setState({ error: null });

  override render(): ReactNode {
    const { error } = this.state;
    if (!error) return this.props.children;

    return (
      <Alert
        severity="error"
        action={
          <Stack direction="row" spacing={1}>
            <Button color="inherit" size="small" onClick={this.reset}>
              Erneut versuchen
            </Button>
            <Button color="inherit" size="small" href="/">
              Startseite
            </Button>
          </Stack>
        }
      >
        <AlertTitle>Das Modul konnte nicht gerendert werden</AlertTitle>
        <Box>
          <Typography variant="body2">{errorMessage(error)}</Typography>
        </Box>
      </Alert>
    );
  }
}