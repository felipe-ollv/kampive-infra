-- Manual transactional checks. Fixture rows are rolled back; identity sequences may advance.
BEGIN;
SET LOCAL search_path TO kampive, public;
SET LOCAL ROLE kampive_app;
DO $$
DECLARE u UUID; cat UUID; camp UUID; rev UUID; n UUID; i INTEGER;
BEGIN
 IF has_schema_privilege(current_user,'kampive','CREATE') OR has_database_privilege(current_user,'kampive','CREATE') THEN RAISE EXCEPTION 'Unexpected DDL privileges'; END IF;
 INSERT INTO app_user(name,email) VALUES ('Schema verification','schema-verification@example.test') RETURNING uuid_app_user INTO u;
 BEGIN
  INSERT INTO app_user(name,email) VALUES ('Duplicate','SCHEMA-VERIFICATION@example.test');
  RAISE EXCEPTION 'Case insensitive email uniqueness failed';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 INSERT INTO campsite_category(name) VALUES ('Schema verification') RETURNING uuid_campsite_category INTO cat;
 INSERT INTO campsite(uuid_owner,uuid_campsite_category,name) VALUES (u,cat,'Schema verification') RETURNING uuid_campsite INTO camp;
 FOR i IN 1..9 LOOP INSERT INTO campsite_photo(uuid_campsite,file_url,sort_order) VALUES(camp,'https://example.test/photo',i); END LOOP;
 BEGIN
  INSERT INTO campsite_photo(uuid_campsite,file_url,sort_order) VALUES(camp,'https://example.test/photo',10);
  RAISE EXCEPTION 'Campsite photo limit failed';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  INSERT INTO campsite_photo(uuid_campsite,file_url,sort_order) VALUES(camp,'https://example.test/photo',1);
  RAISE EXCEPTION 'Photo slot uniqueness failed';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 INSERT INTO review(uuid_app_user,uuid_campsite,rating,comment) VALUES(u,camp,5,repeat('Excellent camping experience. ',3)) RETURNING uuid_review INTO rev;
 FOR i IN 1..3 LOOP INSERT INTO review_photo(uuid_review,file_url,sort_order) VALUES(rev,'https://example.test/photo',i); END LOOP;
 BEGIN
  INSERT INTO review_photo(uuid_review,file_url,sort_order) VALUES(rev,'https://example.test/photo',4);
  RAISE EXCEPTION 'Review photo limit failed';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  UPDATE review SET rating=6 WHERE uuid_review=rev;
  RAISE EXCEPTION 'Rating validation failed';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  INSERT INTO favorite(uuid_app_user,uuid_campsite) VALUES(u,gen_random_uuid());
  RAISE EXCEPTION 'UUID foreign key validation failed';
 EXCEPTION WHEN foreign_key_violation THEN NULL; END;
 IF (SELECT review_count FROM vw_campsite_review_summary WHERE uuid_campsite=camp) <> 0 THEN RAISE EXCEPTION 'Pending review counted'; END IF;
 UPDATE review SET status='published' WHERE uuid_review=rev;
 IF (SELECT average_rating FROM vw_campsite_review_summary WHERE uuid_campsite=camp) <> 5 THEN RAISE EXCEPTION 'Review aggregation failed'; END IF;
 INSERT INTO notification(title,message) VALUES('Verification','Verification') RETURNING uuid_notification INTO n;
 INSERT INTO user_notification(uuid_notification,uuid_app_user) VALUES(n,u);
 IF (SELECT is_read FROM vw_user_notification WHERE uuid_notification=n) THEN RAISE EXCEPTION 'Unread state failed'; END IF;
 UPDATE user_notification SET read_at=CURRENT_TIMESTAMP WHERE uuid_notification=n;
 IF NOT (SELECT is_read FROM vw_user_notification WHERE uuid_notification=n) THEN RAISE EXCEPTION 'Read state failed'; END IF;
 RAISE NOTICE 'All schema behavior checks passed under kampive_app';
END $$;
ROLLBACK;
