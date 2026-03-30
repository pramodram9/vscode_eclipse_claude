namespace mysap.myvscode;

using { cuid, managed } from '@sap/cds/common';

entity Items : cuid, managed {
    title       : String(100)  @mandatory;
    description : String(1000);
    status      : String(20) default 'NEW';
}
