import { LightningElement } from 'lwc';

const HQ_ADDRESS = {
    Street: 'The Landmark @ One Market, Suite 300',
    City: 'San Francisco',
    State: 'CA',
    PostalCode: '94105',
    Country: 'USA'
};

export default class BedrockHqMap extends LightningElement {
    // lightning-map geocodes the address automatically, so no API key is required.
    mapMarkers = [
        {
            location: HQ_ADDRESS,
            title: 'Bedrock Corporate Headquarters',
            description: 'The Landmark @ One Market, Suite 300, San Francisco, CA 94105'
        }
    ];

    // Centering on the marker keeps the pin in view when a high zoom level is applied.
    center = { location: HQ_ADDRESS };

    // 16 is close enough to read the street layout while the city label stays visible.
    zoomLevel = 12;
}
