using { mysap.myvscode as db } from '../db/schema';

service CatalogService @(path: '/catalog') {

    @readonly
    entity Items as projection on db.Items;

}
