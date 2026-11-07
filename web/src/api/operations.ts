import { apiBaseUrl } from './respondaApi';

export async function operations<T>(path: string, body?: unknown, method = 'POST', signal?: AbortSignal): Promise<T> {
  const response = await fetch(`${apiBaseUrl}/api/v1/admin/${path}`, {
    method: body === undefined ? 'GET' : method, credentials: 'include', cache: 'no-store', signal,
    headers: { 'Accept': 'application/json', ...(body === undefined ? {} : { 'Content-Type': 'application/json' }) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) {
    const error = await response.json().catch(() => null);
    throw new Error(typeof error?.error?.message === 'string' ? error.error.message : 'The operation failed. Check your connection and retry.');
  }
  return response.json() as Promise<T>;
}
export type HeatCell = { latitude: number; longitude: number; count: number };
export type ReportAlert = { id: string; title: string; detail: string; time: string; read: boolean };

export async function enableBackgroundAlerts() {
  if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) throw new Error('This browser does not support background alerts. In-app alerts remain available.');
  const {public_key} = await operations<{public_key:string}>('push/key');
  if (await Notification.requestPermission() !== 'granted') throw new Error('Browser notification permission was not granted.');
  const registration = await navigator.serviceWorker.register('/notifications-sw.js');
  await navigator.serviceWorker.ready;
  const normalized = public_key.replaceAll('-', '+').replaceAll('_', '/');
  const bytes = Uint8Array.from(atob(normalized + '='.repeat((4-normalized.length%4)%4)), char=>char.charCodeAt(0));
  const subscription = await registration.pushManager.getSubscription() ?? await registration.pushManager.subscribe({userVisibleOnly:true, applicationServerKey:bytes});
  const data = subscription.toJSON();
  await operations('push/subscriptions', {endpoint:data.endpoint, ...data.keys});
}

export async function disableBackgroundAlerts() {
  const registration = await navigator.serviceWorker.getRegistration('/');
  const subscription = await registration?.pushManager.getSubscription();
  if (subscription) {
    const data = subscription.toJSON();
    await operations('push/unsubscribe',{endpoint:data.endpoint,...data.keys});
    await subscription.unsubscribe();
  }
}
