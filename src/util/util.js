
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
  return correctedDate.toISOString().slice(0,-1);//.split('T')[0]; // just the date portion
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

export function qrToObservation(qr) {

  let observation = {
    resourceType: 'Observation',
    status: 'final',
    effectiveDateTime: getCurrentISODate(),
    subject: qr.subject,
    performer: qr.author,
    encounter: qr.encounter,
    valueCodeableConcept: {
      text: 'WHO AUDIT QuestionnaireResponse'
    },
    component: []
  };

  // Set the Observation code based on the type of Questionnaire
  if (qr.questionnaire == 'http://www.cdc.gov/ncbddd/fasd/audit') {
    observation.code = {
      coding: {
        system: 'http://www.cdc.gov/ncbddd/fasd',
        code: 'audit',
        display: 'Alcohol Use Disorder Identification Test (AUDIT)'
      },
      text: 'WHO AUDIT Questionnaire'
    };
  } else if (qr.questionnaire == 'http://www.cdc.gov/ncbddd/fasd/usaudit') {
    observation.code = {
      coding: {
        system: 'http://www.cdc.gov/ncbddd/fasd',
        code: 'usaudit',
        display: 'U.S. Alcohol Use Disorder Identification Test (AUDIT)'
      },
      text: 'USAUDIT Questionnaire'
    };
  } else if (qr.questionnaire == 'http://www.cdc.gov/ncbddd/fasd/nidaqs2usaudit') {
    observation.code = {
      coding: {
        system: 'http://www.cdc.gov/ncbddd/fasd',
        code: 'nidaqs2usaudit',
        display: 'NIDA Quick Screen to U.S. AUDIT'
      },
      text: 'NIDA Quick Screen to U.S. AUDIT'
    };
  }

  // Capture the responses as components in the Observation
  qr.item.forEach(item => {
    let component = {
      code: {
        coding: [
          {
            code: item.linkId,
            system: 'http://www.cdc.gov/ncbddd/fasd',
            display: item.linkId
          }
        ]
      }
    };
    let answer = item.answer[0];
    if (answer.valueCoding) component.valueCodeableConcept = { coding: [answer.valueCoding] };
    else if (answer.valueDecimal || answer?.valueDecimal == 0) component.valueDecimal = answer.valueDecimal;
    else if (answer.valueBoolean) component.valueBoolean = answer.valueBoolean;
    else component.value = null;
    observation.component.push(component);
  });

  return observation;

}

export function observationToQr(o) {

  if (o.code.coding.system == 'http://www.cdc.gov/ncbddd/fasd') {

    let questionnaireResponse = {
      resourceType: 'QuestionnaireResponse',
      questionnaire: o.code.coding.system + '/' + o.code.coding.code,
      status: 'completed',
      item: [],
      authored: o.effectiveDateTime,
      subject: o.subject,
      author: o.performer,
      encounter: o.encounter
    };

    o.component.forEach(component => {
      let item = {
        linkId: component.code.text
      };
      if (component.valueCodeableConcept) item.answer[0].valueCoding = component.valueCodeableConcept.coding;
      else if (component.valueDecimal) item.answer[0].valueDecimal = component.valueDecimal;
      else if (component.valueBoolean) item.answer[0].valueBoolean = component.valueBoolean;
      else item.answer[0].value = null;
      questionnaireResponse.item.push(item);
    });

    return questionnaireResponse;
  } else {
    return o;
  }

}