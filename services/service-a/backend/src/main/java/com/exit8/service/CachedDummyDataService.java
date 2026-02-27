package com.exit8.service;

import com.exit8.domain.DummyDataRecord;
import com.exit8.repository.DummyDataRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.cache.annotation.Caching;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

/**
 * Cached Dummy Data Service
 * 
 * Provides 2-tier caching (Caffeine L1 + Redis L2) for dummy data operations.
 * 
 * Cache Strategy:
 * - loadTestResults: 60s TTL - for frequently accessed paginated data
 * - referenceData: 24h TTL - for individual records (long-lived)
 * 
 * Cache Flow:
 * 1. Read: Check L1 (Caffeine) -> Check L2 (Redis) -> Load from DB -> Populate both
 * 2. Write: Update DB -> Evict from L1 + L2
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CachedDummyDataService {

    private final DummyDataRepository dummyDataRepository;

    /**
     * Get all records with pagination - Cached
     * 
     * Cache: loadTestResults (60s TTL)
     * Key: Based on pageable parameters (page number, size, sort)
     */
    @Cacheable(
            value = "loadTestResults",
            key = "#pageable.pageNumber + '-' + #pageable.pageSize + '-' + #pageable.sort.toString()",
            unless = "#result == null || #result.isEmpty()"
    )
    public Page<DummyDataRecord> findAllCached(Pageable pageable) {
        log.debug("Cache MISS - Loading from DB: page={}, size={}", 
                pageable.getPageNumber(), pageable.getPageSize());
        return dummyDataRepository.findAll(pageable);
    }

    /**
     * Get record by ID - Cached
     * 
     * Cache: referenceData (24h TTL)
     */
    @Cacheable(
            value = "referenceData",
            key = "#id",
            unless = "#result == null"
    )
    public Optional<DummyDataRecord> findByIdCached(Long id) {
        log.debug("Cache MISS - Loading record from DB: id={}", id);
        return dummyDataRepository.findById(id);
    }

    /**
     * Get all records (no pagination) - Cached
     * 
     * Cache: loadTestResults (60s TTL)
     * Warning: Use with caution for large datasets
     */
    @Cacheable(
            value = "loadTestResults",
            key = "'all-records'",
            unless = "#result == null || #result.isEmpty()"
    )
    public List<DummyDataRecord> findAllCached() {
        log.debug("Cache MISS - Loading all records from DB");
        return dummyDataRepository.findAll();
    }

    /**
     * Save record - Evicts relevant caches
     * 
     * Evicts: loadTestResults (paginated lists), referenceData (individual record)
     */
    @Caching(evict = {
            @CacheEvict(value = "loadTestResults", allEntries = true),
            @CacheEvict(value = "referenceData", key = "#result.id")
    })
    public DummyDataRecord save(DummyDataRecord record) {
        log.debug("Saving record, evicting caches");
        return dummyDataRepository.save(record);
    }

    /**
     * Save and flush - Evicts caches
     */
    @Caching(evict = {
            @CacheEvict(value = "loadTestResults", allEntries = true),
            @CacheEvict(value = "referenceData", allEntries = true)
    })
    public DummyDataRecord saveAndFlush(DummyDataRecord record) {
        log.debug("Save and flush, evicting all caches");
        return dummyDataRepository.saveAndFlush(record);
    }

    /**
     * Delete by ID - Evicts caches
     */
    @Caching(evict = {
            @CacheEvict(value = "loadTestResults", allEntries = true),
            @CacheEvict(value = "referenceData", key = "#id")
    })
    public void deleteById(Long id) {
        log.debug("Deleting record, evicting caches: id={}", id);
        dummyDataRepository.deleteById(id);
    }

    /**
     * Evict all caches manually (for testing/admin)
     */
    @Caching(evict = {
            @CacheEvict(value = "loadTestResults", allEntries = true),
            @CacheEvict(value = "referenceData", allEntries = true)
    })
    public void evictAllCaches() {
        log.info("All caches evicted manually");
    }

    /**
     * Get cache statistics (delegated to CacheMetrics)
     */
    public CacheStats getCacheStats() {
        // This would integrate with CacheMetrics
        return new CacheStats(0, 0, 0.0);
    }

    public record CacheStats(long hits, long misses, double hitRate) {}
}
