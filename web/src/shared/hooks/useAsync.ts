import { useCallback, useState } from 'react';

/** Small helper to run an async callback with loading + error state. */
export function useAsyncAction<TArgs extends unknown[]>(fn: (...args: TArgs) => Promise<unknown>) {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<unknown>(null);

  const run = useCallback(
    async (...args: TArgs) => {
      setPending(true);
      setError(null);
      try {
        return await fn(...args);
      } catch (err) {
        setError(err);
        throw err;
      } finally {
        setPending(false);
      }
    },
    [fn],
  );

  return { run, pending, error };
}
