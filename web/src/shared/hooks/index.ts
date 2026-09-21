import type { ReactNode } from 'react';

export interface DropzoneOptions {
  accept?: string;
  multiple?: boolean;
  onFiles?: (files: File[]) => void;
}

export function useDropzone(_options: DropzoneOptions = {}): {
  open: () => void;
  inputProps: Record<string, unknown>;
} {
  return { open: () => {}, inputProps: {} };
}

export function dropzoneHintText(children: ReactNode): ReactNode {
  return children;
}
