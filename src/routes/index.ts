import http from 'http';

import info from './info';
import genNonces from './gen-nonces';
import claim from './claim';
import getClaimable from './get-claimable';
import coin from './coin';
import feeSchedule from './fee-schedule';
import genInvoice from './gen-invoice';
import lightningInvoiceByClaimant from './lightning-invoice-by-claimant';

import readJson from '../util/read-json';
import addClaimable from './add-claimable';
import getStatusesByClaimable from './get-statuses-by-claimable';
import getClaimableByInputOwner from './get-claimable-by-input-owner';

export default async function runner(req: http.IncomingMessage, res: http.ServerResponse): Promise<any> {
  const url = req.url;
  if (url === undefined) {
    throw new Error('404: missing url');
  }

  switch (url) {
    case '/':
      return info();
    case '/fee-schedule':
      return feeSchedule();
  }
  if (url.startsWith('/claimables/')) {
    return getClaimable(url);
  } else if (url.startsWith('/claimable-by-input-owner/')) {
    return getClaimableByInputOwner(url);
  } else if (url.startsWith('/statuses-by-claimable/')) {
    return getStatusesByClaimable(url);
  } else if (url.startsWith('/coin/')) {
    return coin(url);
  } else if (url.startsWith('/lightning-invoices-by-claimant/')) {
    return lightningInvoiceByClaimant(url);
  }

  if (req.method === 'POST') {
    const body = await readJson(req);
    switch (url) {
      case '/gen-nonces':
        return genNonces(body);
      case '/gen-invoice':
        return genInvoice(body);
      case '/claim':
        return claim(body);
      case '/add-claimable':
        return addClaimable(body);
    }
  }
  console.log('route note found...', url);
}
