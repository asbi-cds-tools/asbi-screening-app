
/**
 * Parses a Questionnaire and determines what value choice (value[x]) each of its items are.
 * @param {object} allOrPartQuestionnaire - A FHIR Questionnaire or a subset of its items
 * @param {array} typeHash - An array containing the value choice (value[x]) for each item
 * @returns {array} typeHash - An array containing the value choice (value[x]) for each item
 */
export function getItemTypes(allOrPartQuestionnaire, typeHash) {
  let items = allOrPartQuestionnaire.item;
  items.forEach(itm => {
    if (itm.type == 'group'){
      typeHash = getItemTypes(itm, typeHash); // recursive function call
    } else if (itm.type == 'boolean') {
      typeHash[itm.linkId] = 'valueBoolean';
    } else {
      typeHash[itm.linkId] = 'valueString'
    }
  });
  return typeHash;
}

export function getCurrentISODate() {
  let now = new Date(Date.now()); // Date.now() returns [millisecods]
  let timeZoneCorrection = now.getTimezoneOffset() * 60 * 1000; // [minutes] * [seconds/minutes] * [milliseconds/second]
  let correctedDate = new Date(now.getTime() - timeZoneCorrection);
  return correctedDate.toISOString().split('T')[0]; // just the date portion
}

export function getObservationCategories() {
  return [
    'social-history',
    'vital-signs',
    'imaging',
    'laboratory',
    'procedure',
    'survey',
    'exam',
    'therapy',
    'activity'
  ]
}

export function getResponseValue(questionnaire, linkId, response) {
  let responseValue = {};
  let questionItemIndex = questionnaire.item.findIndex(itm => itm.linkId == linkId);
  let item = questionnaire.item[questionItemIndex];
  if (item.type == 'choice') {
    let answerOptionIndex = item.answerOption.findIndex(itm => {
      if (itm.valueString && itm.valueString == response) return true;
      if (itm.valueCoding && itm.valueCoding.display == response) return true;
      return false;
    });
    if (item.answerOption[answerOptionIndex].valueString) {
      responseValue.type = 'valueString';
      responseValue.value = response;
    } else if (item.answerOption[answerOptionIndex].valueCoding) {
      responseValue.type = 'valueCoding';
      responseValue.value = item.answerOption[answerOptionIndex].valueCoding;
    } // TODO: ELSE THROW ERROR
  } else if (item.type == 'boolean') {
    responseValue.type = 'valueBoolean';
    responseValue.value = response;
  }
  else if (item.type == 'decimal') {
    responseValue.type = 'valueDecimal';
    responseValue.value = response;
  } else {
    responseValue.type = 'valueCoding';    
    responseValue.value = { display: response };
  }

  return responseValue;

}