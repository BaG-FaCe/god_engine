import { Alert } from '@mui/material';
import { errorMessage } from '../lib/errors';

export function QueryError({ error }: { error: unknown }) {
  return <Alert severity="error">{errorMessage(error)}</Alert>;
}
