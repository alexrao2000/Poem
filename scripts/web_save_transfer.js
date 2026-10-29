/* Native browser text entry for local save codes. No network calls. */
window.ashenSaveTransfer = {
  open(code, receiveCode) {
    const previous = document.getElementById('ashen-save-transfer');
    if (previous) previous.remove();
    const dialog = document.createElement('dialog');
    dialog.id = 'ashen-save-transfer';
    Object.assign(dialog.style, {
      width: 'min(90vw, 850px)', border: '2px solid #a38d61',
      padding: '24px', background: '#f1ead6', color: '#443e36',
      font: '17px system-ui, sans-serif', boxSizing: 'border-box'
    });
    const heading = document.createElement('h2');
    heading.textContent = 'Local save code';
    heading.style.marginTop = '0';
    const help = document.createElement('p');
    help.textContent = 'Copy this code, or replace it with a code from another local build. Use code returns it to the game; Import then loads it.';
    const field = document.createElement('textarea');
    field.setAttribute('aria-label', 'Local save code');
    field.spellcheck = false;
    field.maxLength = 1000000;
    field.value = code;
    Object.assign(field.style, {width: '100%', height: '35vh', boxSizing: 'border-box', font: '13px monospace', padding: '10px'});
    const actions = document.createElement('div');
    Object.assign(actions.style, {display: 'flex', gap: '10px', marginTop: '16px', flexWrap: 'wrap'});
    function button(label, action) {
      const element = document.createElement('button');
      element.type = 'button';
      element.textContent = label;
      Object.assign(element.style, {padding: '12px 20px', font: 'inherit', cursor: 'pointer', background: '#e9dfc5', color: '#443e36', border: '1px solid #a38d61'});
      element.addEventListener('click', action);
      actions.append(element);
    }
    button('Select all', () => { field.focus(); field.select(); });
    button('Use code', () => { receiveCode(field.value); dialog.close(); });
    button('Cancel', () => dialog.close());
    dialog.append(heading, help, field, actions);
    dialog.addEventListener('close', () => { dialog.remove(); document.getElementById('canvas')?.focus(); }, {once: true});
    dialog.addEventListener('keydown', event => event.stopPropagation());
    document.body.append(dialog);
    dialog.showModal();
    field.focus();
    field.select();
  }
};
