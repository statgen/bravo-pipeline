workflow bravoDataPrep {
    # Prepare VCF #
    File inputVCF
    File samplesFile
    Int bufferSize
    String assembly
    String lofOptions
    File refDir
    File refFasta
    File cadScores
    File cadIndex

    # Prepare percentiles #
    String infoField
    Int threads
    Int minMAF
    Int maxMAF
    Int alleleCount
    Int numberPercentiles
    String description
    String outputPrefix

    ###############
    # Prepare VCF #
    ###############

    call computeAlleleCountsAndHistograms {
        input: inputVCF = inputVCF,
            samplesFile = samplesFile,
    }
    call variantEffectPredictor {
        input: inputVCF = computeAlleleCountsAndHistograms.out,
            assembly = assembly,
            lofOptions = lofOptions,
            bufferSize = bufferSize,
            refDir = refDir,
            refFasta = refFasta
    }
    call addCaddScores {
        input: inputVCF = variantEffectPredictor.out,
            cadScores = cadScores,
            cadIndex = cadIndex
    }

    #######################
    # Prepare percentiles #
    #######################

    call computePercentiles {
        input: inputVCF = addCaddScores.out,
            infoField = infoField,
            threads = threads,
            minMAF = minMAF,
            maxMAF = maxMAF,
            alleleCount = alleleCount,
            numberPercentiles = numberPercentiles,
            description = description,
            outputPrefix = outputPrefix
    }
}

task computeAlleleCountsAndHistograms {
    File inputVCF
    File samplesFile

    command {
        ComputeAlleleCountsAndHistograms -i ${inputVCF} -s ${samplesFile} -o computeAlleleCtHst.vcf.gz
    }
    output {
        File out = "computeAlleleCtHst.vcf.gz"
    }
    runtime {
        docker: "statgen/bravo-pipeline:latest"
    }

}

task  variantEffectPredictor {
    File inputVCF
    String assembly
    String lofOptions
    Int bufferSize
    File refDir
    File refFasta

    command {
        vep -i ${inputVCF} \
        --plugin LoF,${lofOptions} \
        --dir_cache ${refDir} \
        --fasta ${refFasta} \
        --assembly ${assembly} \
        --cache \
        --offline \
        --vcf \
        --sift b \
        --polyphen b \
        --ccds \
        --uniprot \
        --hgvs \
        --symbol \
        --numbers \
        --domains \
        --regulatory \
        --canonical \
        --protein \
        --biotype \
        --af \
        --af_1kg \
        --pubmed \
        --shift_hgvs 0 \
        --allele_number \
        --format vcf \
        --force \
        --buffer_size ${bufferSize} \
        --compress_output bgzip \
        --no_stats \
        -o variantEP.vcf.gz
    }
    output {
        File out = "variantEP.vcf.gz"
    }
    runtime {
        docker: "ensemblorg/ensembl-vep:release_95.1"
        cpu: "1"
        bootDiskSizeGb: "150"
    }

}

task addCaddScores {
    File inputVCF
    File cadScores
    File cadIndex

    command {
        add_cadd_scores.py -i ${inputVCF} -c ${cadScores} -o annotated.vcf.gz
    }
    output {
        File out = "annotated.vcf.gz"
    }
    runtime {
        docker: "statgen/bravo-pipeline:latest"
        cpu: "1"
        bootDiskSizeGb: "150"
    }
}

task computePercentiles {
    File inputVCF
    String infoField
    Int threads
    Int minMAF
    Int maxMAF
    Int alleleCount
    Int numberPercentiles
    String description
    String outputPrefix

    command {
        ComputePercentiles -i ${inputVCF} \
        -m ${infoField} \
        -t ${threads} \
        -f ${minMAF} \
        -F ${maxMAF} \
        -a ${alleleCount} \
        -p ${numberPercentiles} \
        -d ${description} \
        -o ${outputPrefix}
    }
    output {
        File outAllPercentiles = "${outputPrefix}.all_percentiles.json.gz"
        File outVariantPercentile = "${outputPrefix}.variant_percentile.vcf.gz"
    }
    runtime {
        docker: "statgen/bravo-pipeline:latest"
        cpu: threads
        bootDiskSizeGb: "150"
    }
}
