on('issues.labeled')
  .filter(context => context.payload.label.name === 'zatwierdzone')
  .close();

on('issues.labeled')
  .filter(context => context.payload.label.name === 'dawno zrobione')
  .close();

on('issues.labeled')
  .filter(context => context.payload.label.name === 'odrzucone')
  .close();
