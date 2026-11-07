/* Browser push contains no narrative, contact or location data. */
self.addEventListener('push', event => {
  let data;
  try { data = event.data.json(); } catch { return; }
  if (!data || !/^[0-9a-f-]{36}$/i.test(data.reportId || '')) return;
  event.waitUntil(self.registration.showNotification('New Responda report', {
    body: 'An emergency report needs staff review.', tag: data.reportId,
    data: {reportId: data.reportId},
  }));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const reportId = event.notification.data?.reportId;
  if (!/^[0-9a-f-]{36}$/i.test(reportId || '')) return;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    for (const client of windows) {
      await client.focus(); client.postMessage({type: 'report-alert', reportId}); return;
    }
    await self.clients.openWindow(`/?report=${encodeURIComponent(reportId)}`);
  })());
});
