export const asNumber = value => {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
};

export const convertCost = (amount, rate) => {
  const cost = asNumber(amount);
  const conversion = asNumber(rate);
  return cost !== null && conversion !== null && conversion > 0
    ? cost * conversion
    : null;
};

export const formatMoney = (value, currency, locale, digits = 4) => {
  const number = asNumber(value);
  if (number === null) return '—';
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currencyDisplay: 'narrowSymbol',
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: digits,
    numberingSystem: 'latn',
  }).format(number);
};

export const formatCount = (value, locale) =>
  new Intl.NumberFormat(locale, { numberingSystem: 'latn' }).format(value);
