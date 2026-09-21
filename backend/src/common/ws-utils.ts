import { WsException } from '@nestjs/websockets';

/**
 * Thrown inside WebSocket handlers; serialized as an ack error
 * with a clean message instead of a generic "Unknown error".
 */
export class WsValidationException extends WsException {
  constructor(message: string) {
    super({ message });
  }
}

/** Normalize any thrown error into a readable string. */
function extractMessage(err: unknown): string {
  if (err instanceof WsException) {
    const anyErr = err as any;
    const inner = anyErr.getError?.() ?? anyErr.message;
    return typeof inner === 'string' ? inner : inner?.message ?? 'Request failed';
  }
  const anyErr = err as any;
  return anyErr?.message ?? 'Something went wrong';
}

/**
 * Wrap async gateway handler bodies: convert thrown errors into
 * { status: 'error', message } ack payloads readable by clients.
 */
export function catchWsError(err: unknown, fallback: string) {
  const message = extractMessage(err) || fallback;
  console.error(`[WS] ${fallback}:`, message);
  return { status: 'error', message };
}
